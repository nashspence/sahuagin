CREATE OR REPLACE FUNCTION get_activation_full_path(activation_id integer)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    result_path text;
BEGIN
    WITH RECURSIVE act_path AS (
        -- Start with the given activation.
        SELECT
            id,
            name,
            from_mechanism,
            root_mechanism,
            to_mechanism,
            name::text AS full_path
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
    SELECT full_path INTO result_path
    FROM act_path
    WHERE NOT EXISTS (
        SELECT 1 
        FROM activation p2
        WHERE p2.to_mechanism = act_path.from_mechanism 
          AND p2.root_mechanism = act_path.root_mechanism
    )
    LIMIT 1;
    
    RETURN result_path;
END;
$$;

