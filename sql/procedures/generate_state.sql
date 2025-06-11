CREATE OR REPLACE PROCEDURE generate_state(
    p_entity_name VARCHAR,
    p_time        DOUBLE PRECISION
)
LANGUAGE plpython3u
AS $$
#
# This implementation uses a generator–based trampoline to preserve immediate child activation
# execution while supporting unmasking (using the stored function check_unmasking) and regeneration.
# All lookups are performed via on–demand SQL queries without in–memory caches.
#

def run_activation(context):
    """
    Run one activation using the context (a dict with keys):
      - mech_id:         mechanism id to run,
      - activation_name: local activation name (None for root),
      - activation_id:   activation id (if already created),
      - root_mech_id:    id of the entity's root mechanism,
      - state_id:        state id,
      - activation_path: full (slash–separated) activation path so far,
      - is_regeneration: boolean flag.
    
    Returns the generator produced by executing the mechanism's main() code.
    """
    current_activation_path = context.get('activation_path', "")

    # --- On–demand regeneration check.
    if context.get('is_regeneration'):
        sql_locked_check = """
            SELECT la.activation 
            FROM locked_activation la 
            WHERE la.state = $1 
              AND get_activation_full_path(la.activation) = $2
            LIMIT 1
        """
        res_locked = plpy.execute(sql_locked_check, [context['state_id'], current_activation_path])
        if res_locked.nrows() > 0:
            # Activation is locked; skip re–execution.
            def empty_gen():
                return
                yield
            return empty_gen()
        # For non–locked activations in regeneration mode, delete previous output rows.
        if context.get('activation_id'):
            plpy.execute(
                "DELETE FROM value WHERE state = $1 AND activation = $2",
                [context['state_id'], context['activation_id']]
            )
    
    # --- On–demand unmasking check for the current activation.
    # For non–root activations, compute parent's activation path and the local name.
    if current_activation_path:
        parent_path, sep, local_name = current_activation_path.rpartition('/')
        if sep == '':
            parent_path = ''
            local_name = current_activation_path
        res_unmask = plpy.execute(
            "SELECT check_unmasking($1, $2, $3) AS unmasked",
            [context['root_mech_id'], parent_path, local_name]
        )
        if res_unmask.nrows() > 0 and res_unmask[0]['unmasked'] is not None:
            context['mech_id'] = res_unmask[0]['unmasked']

    # --- Look up the mechanism record.
    sql = "SELECT id, name, serialized FROM mechanism WHERE id = $1"
    res = plpy.execute(sql, [context['mech_id']])
    if res.nrows() == 0:
        plpy.error("Mechanism with id %s not found" % context['mech_id'])
    mech = res[0]

    # Helper: resolve paths relative to the current activation.
    def resolve_path(input_path, base_path):
        if input_path.startswith("/"):
            return input_path.lstrip("/")
        elif input_path.startswith("./") or input_path.startswith(".."):
            base_components = base_path.split("/") if base_path else []
            resolved_components = list(base_components)
            for part in input_path.split("/"):
                if part in (".", ""):
                    continue
                elif part == "..":
                    if resolved_components:
                        resolved_components.pop()
                    else:
                        plpy.error("Path resolution error: cannot go above the root activation")
                else:
                    resolved_components.append(part)
            return "/".join(resolved_components)
        else:
            return base_path + "/" + input_path if base_path else input_path

    # Inject helper functions for the mechanism code.
    def use_input(path):
        resolved = resolve_path(path, current_activation_path)
        parts = resolved.rsplit("/", 1)
        parent_path = parts[0] if len(parts) > 1 else ""
        output_name = parts[-1]
        sql_val = """
            SELECT v.id AS value_id, v.activation AS antecedent,
                CASE WHEN v.type = 'number'
                        THEN (SELECT serialized FROM number_value WHERE value = v.id)
                        ELSE (SELECT serialized FROM string_value WHERE value = v.id)
                END AS value
            FROM value v
            JOIN activation a ON a.id = v.activation
            WHERE get_activation_full_path(a.id) = $1
            AND v.name = $2
            AND v.state = $3
            LIMIT 1
        """
        res_val = plpy.execute(sql_val, [parent_path, output_name, context['state_id']])
        if res_val.nrows() == 0:
            plpy.error("No output found for resolved path: " + resolved)
        # Record the dependency: current (child) activation used the parent's output.
        plpy.execute(
            "INSERT INTO value_antecedent(value, child, antecedent) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
            [res_val[0]['value_id'], context['activation_id'], res_val[0]['antecedent']]
        )
        return res_val[0]['value']

    def add_output(name, value):
        full_output_path = resolve_path(name, current_activation_path)
        sql_dup = """
            SELECT 1 FROM value 
            WHERE state = $1 AND activation = $2 AND name = $3 
            LIMIT 1
        """
        res_dup = plpy.execute(sql_dup, [context['state_id'], context['activation_id'], name])
        if res_dup.nrows() > 0:
            plpy.error("Output with name '%s' already exists in the current activation" % name)
        value_type_val = 'number' if isinstance(value, (int, float)) else 'string'
        sql_ins = """
            INSERT INTO value(state, activation, name, type)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        """
        res_ins = plpy.execute(sql_ins, [context['state_id'], context['activation_id'], name, value_type_val])
        value_id = res_ins[0]['id']
        if value_type_val == 'number':
            plpy.execute("INSERT INTO number_value(value, serialized) VALUES ($1, $2)", [value_id, float(value)])
        else:
            plpy.execute("INSERT INTO string_value(value, serialized) VALUES ($1, $2)", [value_id, str(value)])
        return value

    def activate(mechanism_name, local_activation_name=None):
        if local_activation_name is None:
            local_activation_name = mechanism_name
        new_activation_path = current_activation_path + "/" + local_activation_name if current_activation_path else local_activation_name
        # Check for duplicate activation on–demand.
        sql_check = "SELECT 1 FROM activation WHERE get_activation_full_path(id) = $1 LIMIT 1"
        res_check = plpy.execute(sql_check, [new_activation_path])
        if res_check.nrows() > 0:
            plpy.error("Activation with name '%s' already exists in the current activation" % local_activation_name)
        # Look up the mechanism id for the requested mechanism.
        sql_lookup = "SELECT id FROM mechanism WHERE name = $1 LIMIT 1"
        res_lookup = plpy.execute(sql_lookup, [mechanism_name])
        if res_lookup.nrows() == 0:
            plpy.error("Mechanism with name %s not found" % mechanism_name)
        new_mech_id = res_lookup[0]['id']

        # Insert a new activation record.
        sql_act = """
            INSERT INTO activation(name, from_mechanism, root_mechanism, to_mechanism)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        """
        res_act = plpy.execute(sql_act, [local_activation_name, context['mech_id'], context['root_mech_id'], new_mech_id])
        new_activation_id = res_act[0]['id']
        # Prepare the child context.
        child_context = {
            'mech_id': new_mech_id,
            'activation_name': local_activation_name,
            'activation_id': new_activation_id,
            'root_mech_id': context['root_mech_id'],
            'state_id': context['state_id'],
            'activation_path': new_activation_path,
            'is_regeneration': context.get('is_regeneration', False)
        }

        # On–demand unmasking for the child activation using the stored function.
        res_child_unmask = plpy.execute(
            "SELECT check_unmasking($1, $2, $3) AS unmasked",
            [context['root_mech_id'], current_activation_path, local_activation_name]
        )
        if res_child_unmask.nrows() > 0 and res_child_unmask[0]['unmasked'] is not None:
            child_context['mech_id'] = res_child_unmask[0]['unmasked']
        yield ("activate", child_context)

    def reject(local_activation_name):
        # Compute the full activation path for the activation to be rejected.
        full_path = current_activation_path + "/" + local_activation_name if current_activation_path else local_activation_name

        # Confirm that the activation exists.
        sql_get = "SELECT id FROM activation WHERE get_activation_full_path(id) = $1 LIMIT 1"
        res_get = plpy.execute(sql_get, [full_path])
        if res_get.nrows() == 0:
            plpy.error("Activation with resolved path %s not found" % full_path)
        
        # Build a pattern to match the rejected activation and any descendant activations.
        pattern = full_path + '%'
        
        # Delete only the values (not the activations) for the current state that belong to the activation chain.
        sql_reject = """
            DELETE FROM value
            WHERE state = $1
            AND activation IN (
                    SELECT a.id FROM activation a
                    WHERE get_activation_full_path(a.id) LIKE $2
            )
        """
        plpy.execute(sql_reject, [context['state_id'], pattern])
    
    # Prepare a namespace for the mechanism code.
    local_ns = {
        'use_input': use_input,
        'add_output': add_output,
        'activate': activate,
        'reject': reject,
    }
    exec(mech['serialized'], local_ns)
    if 'main' not in local_ns:
        plpy.error("Mechanism code does not define a main() generator")
    return local_ns['main']()

def trampoline(root_context):
    """
    The trampoline runs activations with immediate semantics by maintaining an explicit
    stack of (context, generator) pairs. When an activation yields an "activate" instruction,
    the child is executed immediately and control returns to the parent when it completes.
    """
    stack = []
    current_gen = run_activation(root_context)
    stack.append((root_context, current_gen))
    while stack:
        current_context, current_gen = stack[-1]
        try:
            instr = next(current_gen)
        except StopIteration:
            stack.pop()
            continue
        if instr[0] == "activate":
            child_context = instr[1]
            child_gen = run_activation(child_context)
            stack.append((child_context, child_gen))
        else:
            plpy.error("Unknown instruction: " + str(instr))

# --- Main Body of generate_state ---

# 1. Look up the entity and its root mechanism.
sql_entity = "SELECT id, mechanism FROM entity WHERE name = $1 LIMIT 1"
res_entity = plpy.execute(sql_entity, [p_entity_name])
if res_entity.nrows() == 0:
    plpy.error("Entity with name '%s' not found" % p_entity_name)
entity_rec = res_entity[0]
entity_id = entity_rec['id']
root_mech_id = entity_rec['mechanism']

# 2. Look up or create the state for the entity at the given time.
sql_state = "SELECT id FROM state WHERE entity = $1 AND time = $2 LIMIT 1"
res_state = plpy.execute(sql_state, [entity_id, p_time])
if res_state.nrows() == 0:
    res_insert = plpy.execute(
        "INSERT INTO state(entity, time) VALUES ($1, $2) RETURNING id", 
        [entity_id, p_time]
    )
    state_id = res_insert[0]['id']
    is_regeneration = False
else:
    state_id = res_state[0]['id']
    is_regeneration = True

# 3. Prepare the root context.
root_context = {
    'mech_id': root_mech_id,
    'activation_name': None,
    'activation_id': None,
    'root_mech_id': root_mech_id,
    'state_id': state_id,
    'activation_path': "",  # The root activation path is empty.
    'is_regeneration': is_regeneration
}

# 4. Run the trampoline to process all activations synchronously.
trampoline(root_context)

$$;


