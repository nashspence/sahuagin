DO $$
DECLARE
  gender      integer;
  hair_color  integer;
  height      integer;
  human       integer;
  jikry       integer;
  jikry_t0    integer;
  jikry_t1    integer;
  jikry_t2    integer;
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
  CALL generate_entity_state(jikry, 0, NULL, jikry_t0);
  CALL generate_entity_states_in_range(jikry, 1, 200, 1);
END $$;
