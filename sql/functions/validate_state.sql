CREATE OR REPLACE FUNCTION validate_state(
    p_mechanism_name CITEXT,
    p_state_json TEXT
) RETURNS BOOLEAN
LANGUAGE plpython3u
AS $$
import json
module_plan = plpy.prepare("SELECT module FROM mechanism WHERE name = $1", ["citext"])
res = plpy.execute(module_plan, [p_mechanism_name])
if res.nrows() == 0:
    plpy.error("Mechanism with name '%s' not found" % p_mechanism_name)
module_code = res[0]['module']
if module_code is None:
    plpy.error("No module stored for mechanism '%s'" % p_mechanism_name)
state_data = json.loads(p_state_json)

validate_plan = plpy.prepare("SELECT validate_state($1, $2) AS ok", ["citext", "text"])

def delegate(mech_name, part_state):
    res = plpy.execute(validate_plan, [mech_name, json.dumps(part_state)])
    return bool(res[0]['ok'])

def lookup_path(data, path):
    current = data
    for part in path.strip('/').split('/'):
        if part == '':
            continue
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            plpy.error('use_input path not found: %s' % path)
    return current

def use_input(path):
    return lookup_path(state_data, path)

local_ns = {'delegate': delegate, 'use_input': use_input}
exec(module_code, local_ns)
validate_fn = local_ns.get('validate')
if validate_fn is None:
    plpy.error("Mechanism '%s' does not define validate()" % p_mechanism_name)
try:
    return bool(validate_fn(state_data))
except Exception as e:
    plpy.error('Validation failed: %s' % e)
$$;
