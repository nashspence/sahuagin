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



