CREATE OR REPLACE FUNCTION run_test_1()
  RETURNS SETOF entity_state_details
AS $$
DECLARE
  gender      integer;
  hair_color  integer;
  height      integer;
  human       integer;
  jikry       integer;
BEGIN
  CALL add_discrete_attr('Gender', json_build_array('Male', 'Female'), gender);
  CALL add_discrete_attr(
    'Hair Color',
    json_build_array('Blonde', 'Brown', 'Golden', 'Auburn', 'Ginger', 'Sandy', 'Black', 'Gray'),
    hair_color
  );
  CALL add_continuous_attr('Height', 4, TRUE, TRUE, 300, 20, 120, 20, 0, 'inches', height);
  CALL add_variant('Human', json_build_array(gender, hair_color, height), human);
  CALL add_entity('Jikry', human, jikry);
  CALL generate_entity_state(jikry, 0, NULL);
  RETURN QUERY SELECT * FROM get_entity_state_details(jikry, 0);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM run_test_1()
