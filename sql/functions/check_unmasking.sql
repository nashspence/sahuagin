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


