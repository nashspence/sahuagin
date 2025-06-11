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


