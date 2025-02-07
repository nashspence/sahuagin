CALL add_attribute (
    "Gender",
    "discrete",
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);
SET @gender_attr_id = LAST_INSERT_ID();

CALL add_discrete_span(@gender_attr_id, "Male");
CALL add_discrete_span(@gender_attr_id, "Female");

CALL add_variant("Human");
SET @human_var_id = LAST_INSERT_ID();

CALL add_variant_attribute(@human_var_id, @gender_attr_id, "Gender", 0);
SET @human_gender_var_attr = LAST_INSERT_ID();

CALL add_entity("Jikry", @human_var_id);
SET @jikry_entity_id = LAST_INSERT_ID();

CALL generate_entity_state(@jikry_entity_id, 0, NULL);
SET @jikry_at_t0 = LAST_INSERT_ID();