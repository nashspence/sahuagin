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


