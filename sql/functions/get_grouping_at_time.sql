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

