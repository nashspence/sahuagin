CREATE OR REPLACE FUNCTION run_test_1()
  RETURNS TEXT
AS $$
DECLARE
  race        integer;
  gender      integer;
  male        integer;
  female      integer;
  hair_color  integer;
  blonde      integer;
  brown       integer;
  golden      integer;
  auburn      integer;
  ginger      integer;
  sandy       integer;
  black       integer;
  gray        integer;
  height      integer;
  short       integer;
  average     integer;
  tall        integer;
  human       integer;
  human_gender  integer;
  human_hair_color  integer;
  human_height  integer;
  human_red_hair_to_height_var  integer;
  test_humans integer;
BEGIN
  CALL add_discrete_attribute('Gender', gender);
  CALL add_disc_span_to_attr(gender, 'Male', male);
  CALL add_disc_span_to_attr(gender, 'Female', female);

  CALL add_discrete_attribute('Hair Color', hair_color);
  CALL add_disc_span_to_attr(hair_color, 'Blonde', blonde);
  CALL add_disc_span_to_attr(hair_color, 'Brown', brown);
  CALL add_disc_span_to_attr(hair_color, 'Golden', golden);
  CALL add_disc_span_to_attr(hair_color, 'Auburn', auburn);
  CALL add_disc_span_to_attr(hair_color, 'Ginger', ginger);
  CALL add_disc_span_to_attr(hair_color, 'Sandy', sandy);
  CALL add_disc_span_to_attr(hair_color, 'Black', black);
  CALL add_disc_span_to_attr(hair_color, 'Gray', gray);
  CALL modify_disc_span_weight(brown, .5);
  CALL modify_disc_span_weight(gray, .05);

  -- add_continuous_attribute(name, min, mode, max, concentration, skew, precision, show_spans, show_value, units, out p_attr_id)
  CALL add_continuous_attribute('Height', 0, 222, 1000, 100000, 0, 4, TRUE, TRUE, 'in.', height);
  CALL add_cont_span_to_attr(height, 'Short', 0, 100, short);
  CALL add_cont_span_to_attr(height, 'Average', 100, 400, average);
  CALL add_cont_span_to_attr(height, 'Tall', 400, 1000, tall);

  CALL add_variant('Human', human);
  CALL link_attr_to_variant(human, gender, 'Gender', NULL, human_gender);
  CALL link_attr_to_variant(human, hair_color, 'Hair Color', NULL, human_hair_color);
  CALL link_attr_to_variant(human, height, 'Height', NULL, human_height);

  CALL add_variation(ginger, NULL, human_hair_color, NULL, human_height, human_red_hair_to_height_var);

  CALL generate_entity_group(human, 'Test Humans', 'Human %s', 100, test_humans);
  RETURN get_entity_group_state_details(test_humans);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM run_test_1()
