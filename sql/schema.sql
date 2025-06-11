
CREATE EXTENSION IF NOT EXISTS plpython3u;
CREATE EXTENSION IF NOT EXISTS citext;

-- Mechanism table replaces activable, variant, variable, and space.
-- A mechanism is defined by its programming language and serialized code.
-- It must have a unique (non-null) name.
DROP TABLE IF EXISTS mechanism CASCADE;
CREATE TABLE mechanism (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL UNIQUE,
  serialized text NOT NULL
);

-- Activation table now links mechanisms.
-- "from_mechanism" continues through an activation (by name) to the "to_mechanism",
-- and the activation is defined in the context of a "root_mechanism".
-- The unique constraint ensures that (from_mechanism, root_mechanism, name) is unique.
DROP TABLE IF EXISTS activation CASCADE;
CREATE TABLE activation (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL,
  from_mechanism integer NOT NULL,
  root_mechanism integer NOT NULL,
  to_mechanism integer NOT NULL,
  CONSTRAINT uq_activation UNIQUE (from_mechanism, root_mechanism, name),
  CONSTRAINT fk_activation_from FOREIGN KEY (from_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE,
  CONSTRAINT fk_activation_root FOREIGN KEY (root_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE,
  CONSTRAINT fk_activation_to FOREIGN KEY (to_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE
);

-- New table "unmasking"
-- This table provides a reference between a root mechanism, an activation,
-- and a mechanism that is being unmasked (unmasked_to_mechanism).
DROP TABLE IF EXISTS unmasking CASCADE;
CREATE TABLE unmasking (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  root_mechanism integer NOT NULL,
  activation integer NOT NULL,
  unmasked_to_mechanism integer NOT NULL,
  CONSTRAINT fk_unmasking_root FOREIGN KEY (root_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE,
  CONSTRAINT fk_unmasking_activation FOREIGN KEY (activation)
    REFERENCES activation(id) ON DELETE CASCADE,
  CONSTRAINT fk_unmasking_unmasked FOREIGN KEY (unmasked_to_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE
);

-- The entity table now associates an entity with a mechanism.
DROP TABLE IF EXISTS entity CASCADE;
CREATE TABLE entity (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL,
  mechanism integer NOT NULL,
  CONSTRAINT fk_entity_mechanism FOREIGN KEY (mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE
);

-- Snapshot (state) of an entity at a moment in time.
DROP TABLE IF EXISTS state CASCADE;
CREATE TABLE state (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity integer NOT NULL,
  time double precision NOT NULL,
  CONSTRAINT uq_state UNIQUE (entity, time),
  CONSTRAINT fk_state_entity FOREIGN KEY (entity)
    REFERENCES entity(id) ON DELETE CASCADE
);

-- Locked relationships between state and activation for partial re-generation.
DROP TABLE IF EXISTS locked_activation CASCADE;
CREATE TABLE locked_activation (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  state integer NOT NULL,
  activation integer NOT NULL,
  CONSTRAINT fk_locked_activation_state FOREIGN KEY (state)
    REFERENCES state(id) ON DELETE CASCADE,
  CONSTRAINT fk_locked_activation_activation FOREIGN KEY (activation)
    REFERENCES activation(id) ON DELETE CASCADE
);

-- Enum indicating the type of value stored.
DROP TYPE IF EXISTS value_type CASCADE;
CREATE TYPE value_type AS ENUM ('string', 'number');

-- Abstract value representing mechanism states.
DROP TABLE IF EXISTS value CASCADE;
CREATE TABLE value (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  state integer NOT NULL,
  activation integer NOT NULL,
  name citext NOT NULL,
  type value_type NOT NULL,
  CONSTRAINT fk_value_state FOREIGN KEY (state)
    REFERENCES state(id) ON DELETE CASCADE,
  CONSTRAINT fk_value_activation FOREIGN KEY (activation)
    REFERENCES activation(id) ON DELETE CASCADE
);

-- Numeric value.
DROP TABLE IF EXISTS number_value CASCADE;
CREATE TABLE number_value (
  value integer PRIMARY KEY,
  serialized double precision NOT NULL,
  CONSTRAINT fk_number_value FOREIGN KEY (value)
    REFERENCES value(id) ON DELETE CASCADE
);

-- String value.
DROP TABLE IF EXISTS string_value CASCADE;
CREATE TABLE string_value (
  value integer PRIMARY KEY,
  serialized text NOT NULL,
  CONSTRAINT fk_string_value FOREIGN KEY (value)
    REFERENCES value(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS value_antecedent CASCADE;
CREATE TABLE value_antecedent (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    value integer NOT NULL,
    child integer NOT NULL,
    antecedent integer NOT NULL,
    CONSTRAINT fk_value_antecedent_value FOREIGN KEY (value)
        REFERENCES value(id) ON DELETE CASCADE,
    CONSTRAINT fk_value_antecedent_child FOREIGN KEY (child)
        REFERENCES activation(id) ON DELETE CASCADE,
    CONSTRAINT fk_value_antecedent_antecedent FOREIGN KEY (antecedent)
        REFERENCES activation(id) ON DELETE CASCADE,
    UNIQUE (value, child, antecedent)
);

DROP TABLE IF EXISTS locked_dependency CASCADE;
CREATE TABLE locked_dependency (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state integer NOT NULL,
    value integer NOT NULL,
    activation integer NOT NULL,
    CONSTRAINT fk_locked_dependency_state FOREIGN KEY (state)
        REFERENCES state(id) ON DELETE CASCADE,
    CONSTRAINT fk_locked_dependency_value FOREIGN KEY (value)
        REFERENCES value(id) ON DELETE CASCADE,
    CONSTRAINT fk_locked_dependency_activation FOREIGN KEY (activation)
        REFERENCES activation(id) ON DELETE CASCADE,
    UNIQUE (state, value, activation)
);

-- grouping of entity states.
DROP TABLE IF EXISTS grouping CASCADE;
CREATE TABLE grouping (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL UNIQUE
);

-- Entity observed in a grouping.
DROP TABLE IF EXISTS grouping_entity CASCADE;
CREATE TABLE grouping_entity (
  entity integer PRIMARY KEY,
  grouping integer NOT NULL,
  CONSTRAINT fk_grouping_entity_entity FOREIGN KEY (entity)
    REFERENCES entity(id) ON DELETE CASCADE,
  CONSTRAINT fk_grouping_entity_grouping FOREIGN KEY (grouping)
    REFERENCES grouping(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS debug_log CASCADE;
CREATE TABLE debug_log (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_time timestamp DEFAULT CURRENT_TIMESTAMP,
    procedure_name varchar(255),
    log_message text
);

CREATE OR REPLACE FUNCTION debug_log(
    p_procedure_name varchar,
    p_log_message text
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO debug_log (procedure_name, log_message, log_time)
    VALUES (p_procedure_name, p_log_message, now());
END;
$$;

TRUNCATE TABLE debug_log RESTART IDENTITY CASCADE;

SELECT * FROM debug_log;

CREATE OR REPLACE FUNCTION get_activation_full_path(activation_id integer)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    full_path text;
BEGIN
    WITH RECURSIVE act_path AS (
        -- Start with the given activation.
        SELECT 
            id,
            name,
            from_mechanism,
            root_mechanism,
            to_mechanism,
            name AS full_path
        FROM activation
        WHERE id = activation_id

        UNION ALL

        -- Recursively join parent's activation where parent's to_mechanism
        -- matches the child's from_mechanism and they share the same root.
        SELECT 
            p.id,
            p.name,
            p.from_mechanism,
            p.root_mechanism,
            p.to_mechanism,
            p.name || '/' || ap.full_path AS full_path
        FROM activation p
        JOIN act_path ap 
          ON p.to_mechanism = ap.from_mechanism 
         AND p.root_mechanism = ap.root_mechanism
    )
    -- The root activation in the chain will have no parent – i.e. no activation
    -- exists such that its to_mechanism equals this activation's from_mechanism.
    SELECT full_path INTO full_path
    FROM act_path
    WHERE NOT EXISTS (
        SELECT 1 
        FROM activation p2
        WHERE p2.to_mechanism = act_path.from_mechanism 
          AND p2.root_mechanism = act_path.root_mechanism
    )
    LIMIT 1;
    
    RETURN full_path;
END;
$$;

CREATE OR REPLACE FUNCTION check_unmasking(
    p_root_mechanism INTEGER,
    p_parent_activation_path TEXT,
    p_local_activation_name TEXT
) RETURNS INTEGER AS $$
DECLARE
    effective_key TEXT;
    candidate RECORD;
BEGIN
    -- Compute the full activation path for the new activation.
    IF p_parent_activation_path IS NULL OR p_parent_activation_path = '' THEN
        effective_key := p_local_activation_name;
    ELSE
        effective_key := p_parent_activation_path || '/' || p_local_activation_name;
    END IF;

    /*
      For each unmasking record for the given root mechanism,
      compute a candidate effective key by calling the helper
      get_activation_full_path on the stored activation and then:
         candidate_key = (p_parent_activation_path || '/' || get_activation_full_path(u.activation))
         (or just get_activation_full_path(u.activation) if no parent exists)
      Then select the record whose candidate key exactly matches the effective_key.
      If multiple match, pick the one with the deepest relative path.
    */
    SELECT u.unmasked_to_mechanism,
           get_activation_full_path(u.activation) AS rel_path,
           array_length(string_to_array(get_activation_full_path(u.activation), '/'), 1) AS depth
    INTO candidate
    FROM unmasking u
    WHERE u.root_mechanism = p_root_mechanism
      AND (
           CASE 
             WHEN p_parent_activation_path IS NULL OR p_parent_activation_path = '' 
             THEN get_activation_full_path(u.activation)
             ELSE p_parent_activation_path || '/' || get_activation_full_path(u.activation)
           END
         ) = effective_key
    ORDER BY array_length(string_to_array(get_activation_full_path(u.activation), '/'), 1) DESC
    LIMIT 1;

    IF candidate IS NULL THEN
       RETURN NULL;
    ELSE
       RETURN candidate.unmasked_to_mechanism;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE create_mechanism(
    p_mechanism_name CITEXT,
    p_serialized_code TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mech_id INTEGER;
BEGIN
    INSERT INTO mechanism (name, serialized)
    VALUES (p_mechanism_name, p_serialized_code)
    RETURNING id INTO v_mech_id;
    
    RAISE NOTICE 'Mechanism "%" created with id %.', p_mechanism_name, v_mech_id;
EXCEPTION 
    WHEN unique_violation THEN
        RAISE EXCEPTION 'A mechanism with name "%" already exists.', p_mechanism_name;
END;
$$;


CREATE OR REPLACE PROCEDURE create_unmasking(
    p_root_mechanism_name CITEXT,
    p_activation_path TEXT,
    p_unmasked_to_mechanism_name CITEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_root_mech_id         INTEGER;
    v_unmasked_to_mech_id  INTEGER;
    v_activation_id        INTEGER;
BEGIN
    -- Lookup the root mechanism by its human-readable name.
    SELECT id INTO v_root_mech_id
      FROM mechanism
     WHERE name = p_root_mechanism_name;
    IF v_root_mech_id IS NULL THEN
        RAISE EXCEPTION 'No mechanism found with name "%" for root mechanism.', p_root_mechanism_name;
    END IF;

    -- Lookup the unmasked-to mechanism by its name.
    SELECT id INTO v_unmasked_to_mech_id
      FROM mechanism
     WHERE name = p_unmasked_to_mechanism_name;
    IF v_unmasked_to_mech_id IS NULL THEN
        RAISE EXCEPTION 'No mechanism found with name "%" for unmasked mechanism.', p_unmasked_to_mechanism_name;
    END IF;

    -- Retrieve the activation record using the helper function.
    SELECT a.id INTO v_activation_id
      FROM activation a
     WHERE get_activation_full_path(a.id) = p_activation_path
       AND a.root_mechanism = v_root_mech_id;
    IF v_activation_id IS NULL THEN
        RAISE EXCEPTION 'No activation found with path "%" under root mechanism "%".', p_activation_path, v_root_mech_id;
    END IF;

    -- Insert the unmasking record.
    INSERT INTO unmasking (root_mechanism, activation, unmasked_to_mechanism)
    VALUES (v_root_mech_id, v_activation_id, v_unmasked_to_mech_id);

    RAISE NOTICE 'Unmasking record created: root mechanism "%" | activation path "%" | unmasked to mechanism "%".',
      p_root_mechanism_name, p_activation_path, p_unmasked_to_mechanism_name;

    ----------------------------------------------------------------------------
    -- Delete entire state records for any entity whose state includes an activation
    -- (or descendant activations) that ever depended on the specified root mechanism.
    -- This avoids partial regeneration entirely.
    ----------------------------------------------------------------------------
    DELETE FROM state
    WHERE id IN (
        SELECT DISTINCT s.id
        FROM state s
        JOIN value v ON v.state = s.id
        JOIN activation a ON a.id = v.activation
        WHERE check_unmasking(
                  v_root_mech_id,
                  CASE 
                    WHEN strpos(get_activation_full_path(a.id), '/') > 0 
                      THEN substring(get_activation_full_path(a.id) from '^(.*)/')
                    ELSE ''
                  END,
                  a.name
              ) = v_unmasked_to_mech_id
    );
END;
$$;

CREATE OR REPLACE PROCEDURE lock_value(
    p_entity_name VARCHAR,
    p_time DOUBLE PRECISION,
    p_activation_path VARCHAR,  -- Full activation path where the target value was produced.
    p_value_name VARCHAR        -- Name of the target value.
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_entity_id INTEGER;
    v_state_id INTEGER;
    v_value_id INTEGER;
BEGIN
    -- Look up the entity.
    SELECT id INTO v_entity_id FROM entity WHERE name = p_entity_name;
    IF v_entity_id IS NULL THEN
        RAISE EXCEPTION 'Entity "%" not found', p_entity_name;
    END IF;

    -- Look up the state.
    SELECT id INTO v_state_id FROM state WHERE entity = v_entity_id AND time = p_time;
    IF v_state_id IS NULL THEN
        RAISE EXCEPTION 'State for entity "%" at time % not found', p_entity_name, p_time;
    END IF;

    -- Find the target value (its id) produced by the given activation.
    SELECT v.id INTO v_value_id
    FROM value v
    JOIN activation a ON a.id = v.activation
    WHERE v.state = v_state_id
      AND v.name = p_value_name
      AND get_activation_full_path(a.id) = p_activation_path
    LIMIT 1;
    IF v_value_id IS NULL THEN
        RAISE EXCEPTION 'Value "%" not found in state with activation path %', p_value_name, p_activation_path;
    END IF;

    -- Compute full dependency closure for the target value.
    WITH RECURSIVE lock_chain(act) AS (
       -- Start with the activation that produced the target value.
       SELECT v.activation
       FROM value v
       WHERE v.state = v_state_id
         AND v.id = v_value_id
       UNION
       -- Walk upward: any activation that produced an input used by an activation in the chain.
       SELECT va.antecedent
       FROM value_antecedent va
       JOIN lock_chain lc ON va.child = lc.act
       UNION
       -- Walk downward: any activation that used an output from an activation in the chain.
       SELECT va.child
       FROM value_antecedent va
       JOIN lock_chain lc ON va.antecedent = lc.act
    )
    -- Record for each activation in the dependency closure that it is locked by this value.
    INSERT INTO locked_dependency(state, value, activation)
    SELECT v_state_id, v_value_id, act FROM lock_chain
    ON CONFLICT DO NOTHING;

    -- Ensure each activation in the closure is in locked_activation.
    INSERT INTO locked_activation(state, activation)
    SELECT v_state_id, act FROM lock_chain
    ON CONFLICT DO NOTHING;
END;
$$;

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

CREATE OR REPLACE FUNCTION get_state(
    p_entity_name VARCHAR,
    p_time DOUBLE PRECISION
)
RETURNS TABLE (
    "index" BIGINT,
    address VARCHAR,
    value_type value_type,
    value TEXT,
    locked BOOLEAN
)
LANGUAGE sql
AS $$
WITH state_info AS (
  SELECT s.id AS state_id, e.mechanism AS root_mech_id, e.name AS entity_name
  FROM state s
  JOIN entity e ON e.id = s.entity
  WHERE e.name = p_entity_name AND s.time = p_time
),
all_values AS (
  SELECT v.*, 
         a.name AS local_activation,
         get_activation_full_path(a.id) AS activation_path
  FROM value v
  JOIN activation a ON a.id = v.activation
  JOIN state_info si ON si.state_id = v.state
)
SELECT 
  row_number() OVER (ORDER BY activation_path) AS "index",
  activation_path || '/' || v.name AS address,
  v.type AS value_type,
  CASE 
    WHEN v.type = 'number' THEN (
         SELECT nv.serialized::text 
         FROM number_value nv 
         WHERE nv.value = v.id
    )
    ELSE (
         SELECT sv.serialized 
         FROM string_value sv 
         WHERE sv.value = v.id
    )
  END AS value,
  EXISTS (
     SELECT 1 
     FROM locked_activation la 
     WHERE la.activation = v.activation AND la.state = v.state
  ) AS locked
FROM all_values v
ORDER BY activation_path;
$$;

CREATE OR REPLACE PROCEDURE generate_grouping(
    p_mechanism_name         VARCHAR,
    p_grouping_name          VARCHAR,
    p_entity_name_template   VARCHAR,
    p_num_entities           INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mech_id      INTEGER;
    v_grouping_id  INTEGER;
    v_entity_id    INTEGER;
    v_idx          INTEGER;
    v_entity_name  VARCHAR;
BEGIN
    -- Look up the mechanism id using the mechanism name.
    SELECT id INTO v_mech_id FROM mechanism WHERE name = p_mechanism_name;
    IF v_mech_id IS NULL THEN
        RAISE EXCEPTION 'No mechanism found with name=%', p_mechanism_name;
    END IF;
    
    -- Create a new grouping.
    INSERT INTO grouping (name)
    VALUES (p_grouping_name)
    RETURNING id INTO v_grouping_id;
    
    FOR v_idx IN 1..p_num_entities LOOP
        v_entity_name := format(p_entity_name_template, v_idx);
        
        -- Create a new entity using the looked-up mechanism id.
        INSERT INTO entity (mechanism, name)
        VALUES (v_mech_id, v_entity_name)
        RETURNING id INTO v_entity_id;
        
        INSERT INTO grouping_entity (entity, grouping)
        VALUES (v_entity_id, v_grouping_id);
        
        -- Call generate_state for the new entity at time 0.
        CALL generate_state(v_entity_name, 0);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION get_grouping_at_time(
    p_grouping_name VARCHAR,
    p_time DOUBLE PRECISION
)
RETURNS TABLE (
    entity_name VARCHAR,
    state_id INTEGER,
    address VARCHAR,
    value_type value_type,
    value TEXT,
    locked BOOLEAN
)
LANGUAGE sql
AS $$
WITH grp AS (
  SELECT id FROM grouping WHERE name = p_grouping_name
),
ent AS (
  SELECT e.id, e.name
  FROM entity e
  JOIN grouping_entity ge ON e.id = ge.entity
  WHERE ge.grouping = (SELECT id FROM grp)
),
st AS (
  SELECT e.id AS entity_id, e.name AS entity_name, s.id AS state_id
  FROM ent e
  JOIN state s ON s.entity = e.id
  WHERE s.time = p_time
)
SELECT 
  st.entity_name,
  st.state_id,
  es.address,
  es.value_type,
  es.value,
  es.locked
FROM st
CROSS JOIN LATERAL (
    SELECT *
    FROM get_state(st.entity_name, p_time)
) es
ORDER BY st.entity_name, es."index";
$$;

