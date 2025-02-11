CREATE OR REPLACE FUNCTION run_test_1()
  RETURNS TEXT
AS $$
DECLARE
  race        integer;
  gender      integer;
  hair_color  integer;
  height      integer;
  human       integer;
  test_humans integer;
BEGIN
  CALL add_discrete_attr('Race', json_build_array('Male', 'Female'), gender);
  CALL add_discrete_attr('Gender', json_build_array('Male', 'Female'), gender);
  CALL add_discrete_attr(
    'Hair Color',
    json_build_array('Blonde', 'Brown', 'Golden', 'Auburn', 'Ginger', 'Sandy', 'Black', 'Gray'),
    hair_color
  );
  CALL add_continuous_attr('Height', 4, TRUE, TRUE, 0, 222, 1000, 100000, 0, 'in.', height);
  CALL add_variant('Human', json_build_array(gender, hair_color, height), human);
  CALL generate_entities_in_group(human, 'Test Humans', 'Human %s', 100, test_humans);
  RETURN get_entity_group_state_details(test_humans);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM run_test_1()
