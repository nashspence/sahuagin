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

