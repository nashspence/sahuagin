CALL add_attribute ("Gender", "discrete", NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
SET @gender = LAST_INSERT_ID();

CALL add_discrete_span(@gender, "Male");
CALL add_discrete_span(@gender, "Female");

CALL add_attribute (
    "Hair Color",
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
SET @hair_color = LAST_INSERT_ID();

CALL add_discrete_span(@hair_color, "Blonde");
SET @blonde_span = LAST_INSERT_ID();
CALL add_discrete_span(@hair_color, "Brown");
SET @brown_span = LAST_INSERT_ID();
CALL add_discrete_span(@hair_color, "Golden");
SET @golden_span = LAST_INSERT_ID();
CALL add_discrete_span(@hair_color, "Auburn");
SET @auburn_span = LAST_INSERT_ID();
CALL add_discrete_span(@hair_color, "Ginger");
SET @ginger_span = LAST_INSERT_ID();
CALL add_discrete_span(@hair_color, "Sandy");
SET @sandy_span = LAST_INSERT_ID();
CALL add_discrete_span(@hair_color, "Black");
SET @black_span = LAST_INSERT_ID();
CALL add_discrete_span(@hair_color, "Gray");
SET @gray_span = LAST_INSERT_ID();

CALL set_discrete_span_percentage(@brown_span, .5)

CALL add_variant("Human");
SET @human = LAST_INSERT_ID();

CALL add_variant_attribute(@human, @gender, "Gender", 0);
SET @human_gender = LAST_INSERT_ID();
CALL add_variant_attribute(@human, @hair_color, "Hair Color", 1);
SET @human_hair_color = LAST_INSERT_ID();

CALL add_entity("Jikry", @human);
SET @jikry = LAST_INSERT_ID();

CALL generate_entity_state(@jikry, 0, NULL);
SET @jikry_t0 = LAST_INSERT_ID();