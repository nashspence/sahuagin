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

    -- Compute full dependency closure for the target value and populate locks.
    WITH RECURSIVE lock_chain(act) AS (
        -- Start with the activation that produced the target value.
        SELECT v.activation
        FROM value v
        WHERE v.state = v_state_id
          AND v.id = v_value_id
        UNION
        -- Walk both upward and downward through value_antecedent.
        SELECT rel.act
        FROM (
            SELECT child AS child, antecedent AS act FROM value_antecedent
            UNION
            SELECT antecedent AS child, child AS act FROM value_antecedent
        ) rel
        JOIN lock_chain lc ON rel.child = lc.act
    )
    INSERT INTO locked_dependency(state, value, activation)
    SELECT v_state_id, v_value_id, act FROM lock_chain
    ON CONFLICT DO NOTHING;

    WITH RECURSIVE lock_chain(act) AS (
        SELECT v.activation
        FROM value v
        WHERE v.state = v_state_id
          AND v.id = v_value_id
        UNION
        SELECT rel.act
        FROM (
            SELECT child AS child, antecedent AS act FROM value_antecedent
            UNION
            SELECT antecedent AS child, child AS act FROM value_antecedent
        ) rel
        JOIN lock_chain lc ON rel.child = lc.act
    )
    INSERT INTO locked_activation(state, activation)
    SELECT v_state_id, act FROM lock_chain
    ON CONFLICT DO NOTHING;
END;
$$;


