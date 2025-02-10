--#region "debug_log"

CREATE OR REPLACE FUNCTION debug_log(
    p_procedure_name varchar,
    p_log_message text
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO debug_log (procedure_name, log_message, log_time)
    VALUES (p_procedure_name, p_log_message, now());
END;
$$;

--#endregion
--#region "add_discrete_span"

CREATE OR REPLACE PROCEDURE add_discrete_span(
    p_attribute_id INTEGER,
    p_label VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_weight    DOUBLE PRECISION;
    v_pinned_weight   DOUBLE PRECISION;
    v_target          DOUBLE PRECISION;
    v_count_old       INTEGER;
    v_new_count       INTEGER;
    candidate         DOUBLE PRECISION;
BEGIN
    -- Get the total weight for all discrete spans for this attribute.
    SELECT COALESCE(SUM(weight), 0)
      INTO v_total_weight
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete';
       
    -- If no spans exist, simply insert the first span with weight 1.
    IF v_total_weight = 0 THEN
        INSERT INTO span(attribute_id, label, type, is_percentage_pinned, weight)
        VALUES (p_attribute_id, p_label, 'discrete', false, 1.0);
        RETURN;
    END IF;
    
    -- Compute the total weight of pinned spans.
    SELECT COALESCE(SUM(weight), 0)
      INTO v_pinned_weight
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = true;
       
    -- The available weight for all non-pinned spans.
    v_target := 1.0 - v_pinned_weight;
    
    IF v_target <= 0 THEN
        RAISE EXCEPTION 'No available weight for unpinned spans (v_target = %)', v_target;
    END IF;
    
    -- Count the existing non-pinned discrete spans.
    SELECT COUNT(*)
      INTO v_count_old
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = false;
       
    -- Insert the new unpinned span with a temporary weight of 0.
    INSERT INTO span(attribute_id, label, type, is_percentage_pinned, weight)
    VALUES (p_attribute_id, p_label, 'discrete', false, 0.0);
    
    v_new_count := v_count_old + 1;
    candidate := v_target / v_new_count;
    
    -- Recalculate every unpinned span’s weight:
    -- • The newly inserted span (identified by its label) is given the candidate weight.
    -- • Each pre-existing unpinned span is scaled proportionally so that its new weight is:
    --       old_weight * ((v_target - candidate) / v_target)
    UPDATE span
       SET weight = CASE 
                      WHEN label = p_label THEN candidate
                      ELSE weight * ((v_target - candidate) / v_target)
                    END
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = false;
END;
$$;

--#endregion
--#region "add_discrete_attr"

CREATE OR REPLACE PROCEDURE add_discrete_attr(
    in_name       VARCHAR(255),
    in_spans      JSON,  -- JSON array: either [["span1", 10], ["span2", 20]] or ["span1", "span2"]
    OUT out_attr_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_attr_id   INTEGER;
    i             INTEGER := 0;
    span_count    INTEGER;
    span_label    VARCHAR(255);
    span_weight   INTEGER;
    first_elem_type TEXT;
    spans_json    JSON;
BEGIN
    INSERT INTO attribute (name, type)
      VALUES (in_name, 'discrete')
      RETURNING id INTO new_attr_id;

    IF in_spans IS NOT NULL THEN
        spans_json := in_spans::json;
        span_count := json_array_length(spans_json);

        IF span_count > 0 THEN
            first_elem_type := json_typeof(spans_json->0);
        ELSE
            first_elem_type := '';
        END IF;

        WHILE i < span_count LOOP
            IF first_elem_type = 'array' THEN
                span_label := (spans_json->i)->>0;
                span_weight := ((spans_json->i)->>1)::INTEGER;
                INSERT INTO span (attribute_id, label, type, is_percentage_pinned, weight)
                  VALUES (new_attr_id, span_label, 'discrete', false, span_weight);
            ELSE
                span_label := spans_json->>i;
                CALL add_discrete_span(new_attr_id, span_label);
            END IF;
            i := i + 1;
        END LOOP;
    END IF;

    out_attr_id := new_attr_id;
END;
$$;

--#endregion
--#region "add_continuous_attr"

CREATE OR REPLACE PROCEDURE add_continuous_attr(
    p_name           VARCHAR(255),
    p_decimals       INTEGER,
    p_has_labels     BOOLEAN,
    p_has_value      BOOLEAN,
    p_max_value      DOUBLE PRECISION,
    p_min_value      DOUBLE PRECISION,
    p_normal_value   DOUBLE PRECISION,
    p_percent_normal DOUBLE PRECISION,
    p_percent_skewed DOUBLE PRECISION,
    p_units          VARCHAR(255),
    OUT p_attr_id    INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO attribute
      (name, type, decimals, has_labels, has_value, max_value, min_value,
       normal_value, percent_normal, percent_skewed, units)
    VALUES
      (p_name, 'continuous', p_decimals, p_has_labels, p_has_value, p_max_value,
       p_min_value, p_normal_value, p_percent_normal, p_percent_skewed, p_units)
    RETURNING id INTO p_attr_id;
END;
$$;

--#endregion
--#region "add_variant_attribute"

CREATE OR REPLACE PROCEDURE add_variant_attribute(
    p_variant_id   INTEGER,
    p_attribute_id INTEGER,
    p_name         VARCHAR,
    p_position     INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_count    INTEGER;
    v_position INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
      FROM variant_attribute
     WHERE variant_id = p_variant_id;
    
    IF p_position IS NULL THEN
        v_position := v_count;  -- append at end
    ELSE
        v_position := p_position;
        IF v_position < 0 THEN 
            v_position := 0;
        END IF;
        IF v_position > v_count THEN
            v_position := v_count;
        END IF;
        UPDATE variant_attribute
           SET causation_index = causation_index + 1
         WHERE variant_id = p_variant_id
           AND causation_index >= v_position;
    END IF;

    INSERT INTO variant_attribute(attribute_id, name, causation_index, variant_id)
    VALUES (p_attribute_id, p_name, v_position, p_variant_id);
END;
$$;

--#endregion
--#region "add_variant"

CREATE OR REPLACE PROCEDURE add_variant(
    in_variant_name VARCHAR,
    in_attr_keys    JSON,
    OUT out_variant_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_variant_id INTEGER;
    i INTEGER := 0;
    key_count INTEGER;
    attr_key INTEGER;
    attr_name VARCHAR;
BEGIN
    INSERT INTO variant (name)
    VALUES (in_variant_name)
    RETURNING id INTO new_variant_id;
    out_variant_id := new_variant_id;

    IF in_attr_keys IS NOT NULL THEN
        key_count := json_array_length(in_attr_keys::json);
        WHILE i < key_count LOOP
            -- Get the JSON array element at position i and cast to integer.
            attr_key := (in_attr_keys::json ->> i)::integer;
            SELECT name
              INTO attr_name
              FROM attribute
             WHERE id = attr_key
             LIMIT 1;
            CALL add_variant_attribute(new_variant_id, attr_key, attr_name, NULL);
            i := i + 1;
        END LOOP;
    END IF;
END;
$$;

--#endregion
--#region "add_entity"

CREATE OR REPLACE PROCEDURE add_entity(
    in_name VARCHAR(255),
    in_variant_id INT,
    OUT out_entity_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO entity(name, variant_id)
    VALUES (in_name, in_variant_id)
    RETURNING id INTO out_entity_id;
END;
$$;

--#endregion
--#region "roll_discrete_varattr"

CREATE OR REPLACE FUNCTION roll_discrete_varattr(
    p_variant_attribute_id         INTEGER,
    p_variant_attr_variant_span_id INTEGER,
    p_exclude_span_id              INTEGER
) 
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_span_id INTEGER;
    v_max_double constant double precision := 1e308;
BEGIN
    PERFORM debug_log(
        'roll_discrete_varattr',
        'Start: p_variant_attribute_id=' || p_variant_attribute_id ||
        ', p_variant_attr_variant_span_id=' || p_variant_attr_variant_span_id ||
        ', p_exclude_span_id=' || p_exclude_span_id
    );

    WITH
    BaseSpans AS (
         SELECT s.id AS span_id, 
                va.id AS variant_attribute_id, 
                vas.id AS variant_attr_span_id, 
                s.weight AS base_weight
         FROM variant_attribute va
         JOIN span s ON s.attribute_id = va.attribute_id
         LEFT JOIN variant_attr_span vas 
           ON vas.variant_attribute_id = va.id 
          AND vas.span_id = s.id
         WHERE va.id = p_variant_attribute_id 
           AND s.type = 'discrete'
           AND (p_exclude_span_id = 0 OR s.id <> p_exclude_span_id)
    ), 
    ActiveVariations AS (
         SELECT v.id AS variation_id, 
                vav.variant_attribute_id
         FROM variation v
         JOIN vavspan_attr vav 
           ON vav.id = v.to_modify_vavspan_attr_id 
          AND vav.variant_attribute_id = p_variant_attribute_id
         WHERE v.is_inactive = false
    ), 
    InactiveSpans AS (
         SELECT DISTINCT vis.span_id
         FROM variation_inactive_span vis
         JOIN ActiveVariations av 
           ON av.variation_id = vis.variation_id
    ), 
    ActivatedSpans AS (
         SELECT DISTINCT 
                vas.span_id, 
                av.variant_attribute_id, 
                NULL::INTEGER AS variant_attr_span_id, 
                0.0 AS base_weight
         FROM variation_activated_span vas
         JOIN ActiveVariations av 
           ON av.variation_id = vas.variation_id
    ), 
    DeltaWeights AS (
         SELECT vdw.span_id, 
                SUM(vdw.delta_weight) AS total_delta
         FROM variation_delta_weight vdw
         JOIN ActiveVariations av 
           ON av.variation_id = vdw.variation_id
         GROUP BY vdw.span_id
    ), 
    AllRelevantSpans AS (
         SELECT b.span_id, b.variant_attribute_id, b.variant_attr_span_id, b.base_weight
         FROM BaseSpans b
         WHERE b.span_id NOT IN (SELECT span_id FROM InactiveSpans)
         UNION
         SELECT a.span_id, a.variant_attribute_id, a.variant_attr_span_id, a.base_weight
         FROM ActivatedSpans a
         WHERE a.span_id NOT IN (SELECT span_id FROM InactiveSpans)
    ), 
    FinalSpans AS (
         SELECT ars.span_id, 
                ars.variant_attribute_id, 
                ars.variant_attr_span_id,
                COALESCE(ars.base_weight, 0) + COALESCE(dw.total_delta, 0) AS effective_weight
         FROM AllRelevantSpans ars
         LEFT JOIN DeltaWeights dw 
           ON dw.span_id = ars.span_id
    ),
    SpanCounts AS (
         SELECT ns.num_spans, 
                SUM(fs.effective_weight / ns.num_spans) AS total_weight
         FROM FinalSpans fs
         CROSS JOIN (
             SELECT COUNT(*)::double precision AS num_spans 
             FROM FinalSpans 
             WHERE effective_weight > 0
         ) ns
         WHERE fs.effective_weight > 0
         GROUP BY ns.num_spans
    ),
    AdjustedSpans AS (
         SELECT fs.span_id,
                fs.variant_attribute_id,
                fs.variant_attr_span_id,
                fs.effective_weight,
                sc.num_spans,
                sc.total_weight,
                CASE 
                  WHEN fs.effective_weight < 1 
                    THEN ceil((fs.effective_weight * v_max_double) / (sc.total_weight * sc.num_spans))
                  ELSE ceil((fs.effective_weight / (sc.total_weight * sc.num_spans)) * v_max_double)
                END AS adjusted_weight
         FROM FinalSpans fs
         CROSS JOIN SpanCounts sc
         WHERE fs.effective_weight > 0
    ),
    Running AS (
         SELECT span_id,
                variant_attribute_id,
                variant_attr_span_id,
                adjusted_weight,
                SUM(adjusted_weight) OVER (ORDER BY span_id) AS running_total
         FROM AdjustedSpans
    ),
    OrderedSpansCTE AS (
         SELECT span_id,
                variant_attribute_id,
                variant_attr_span_id,
                adjusted_weight AS contextual_weight,
                running_total,
                LAG(running_total, 1, 0) OVER (ORDER BY span_id) AS prev_running_total
         FROM Running
    ),
    TotalAdjusted AS (
         SELECT MAX(running_total) AS v_total_weight
         FROM OrderedSpansCTE
    ),
    Rng AS (
         SELECT t.v_total_weight,
                floor(random() * t.v_total_weight) AS v_random_pick
         FROM TotalAdjusted t
    )
    SELECT o.span_id
      INTO v_span_id
      FROM OrderedSpansCTE o, Rng
      WHERE Rng.v_random_pick >= o.prev_running_total
        AND Rng.v_random_pick < o.running_total
      LIMIT 1;

    PERFORM debug_log(
        'roll_discrete_varattr',
        'Chosen v_span_id=' || COALESCE(v_span_id::text, 'NULL')
    );

    RETURN v_span_id;
END;
$$;

--#endregion
--#region "roll_continuous_varattr"

CREATE OR REPLACE FUNCTION roll_continuous_varattr(
    p_variant_attribute_id         integer,
    p_variant_attr_variant_span_id integer,
    p_exclude_span_id              integer
)
RETURNS TABLE(chosen_span_id integer, chosen_value double precision)
LANGUAGE plpgsql
AS $$
DECLARE
    v_attribute_id              integer;
    v_decimals                  integer;
    v_min                       double precision;
    v_max                       double precision;
    v_normal                    double precision;
    v_percent_normal            double precision;
    v_percent_skewed            double precision;
    v_total_delta_normal        double precision := 0;
    v_total_delta_pnormal       double precision := 0;
    v_total_delta_pskew         double precision := 0;
    v_eff_min                   double precision;
    v_eff_max                   double precision;
    v_eff_normal                double precision;
    v_tmp                       double precision;
    v_total_discrete_values     double precision;
    v_random_uniform            double precision;
    v_midpoint                  double precision;
    v_skew_offset               double precision;
    v_normal_offset             double precision;
    v_degree_estimate           double precision;
    v_mult                      double precision;
    v_discrete_degree_estimate  double precision;
    v_cubic_degree_estimate     double precision;
    v_skewed                    double precision;
    v_distributed               double precision;
    v_multiplier                double precision;
    v_avg                       double precision;
    v_offset                    double precision;
    v_result                    double precision;
    v_clamped_result            double precision;
    v_chosen_span_id            integer;
    dummy_eff_min               double precision;
    dummy_eff_max               double precision;
BEGIN
    PERFORM debug_log(
        'roll_continuous_varattr',
        'Start: p_variant_attribute_id=' || p_variant_attribute_id ||
        ', p_variant_attr_variant_span_id=' || p_variant_attr_variant_span_id ||
        ', p_exclude_span_id=' || p_exclude_span_id
    );

    -- Retrieve attribute details.
    SELECT va.attribute_id,
           a.decimals,
           a.min_value,
           a.max_value,
           a.normal_value,
           a.percent_normal,
           a.percent_skewed
      INTO v_attribute_id, v_decimals, v_min, v_max, v_normal, v_percent_normal, v_percent_skewed
      FROM variant_attribute va
      JOIN attribute a ON a.id = va.attribute_id
     WHERE va.id = p_variant_attribute_id
     LIMIT 1;

    IF v_attribute_id IS NULL THEN
        RAISE EXCEPTION 'No matching attribute found';
    END IF;

    PERFORM debug_log(
        'roll_continuous_varattr',
        'Retrieved attribute details: attribute_id=' || v_attribute_id || ', decimals=' || v_decimals
    );

    -- Sum variation deltas.
    SELECT COALESCE(SUM(vca.delta_normal), 0),
           COALESCE(SUM(vca.delta_percent_normal), 0),
           COALESCE(SUM(vca.delta_percent_skewed), 0)
      INTO v_total_delta_normal, v_total_delta_pnormal, v_total_delta_pskew
      FROM variation_continuous_attr vca
      JOIN (
            SELECT v.id
              FROM variation v
              JOIN vavspan_attr vav ON vav.id = v.to_modify_vavspan_attr_id
             WHERE vav.variant_attribute_id = p_variant_attribute_id
               AND vav.id = p_variant_attr_variant_span_id
               AND v.is_inactive = false
           ) av ON av.id = vca.variation_id;

    PERFORM debug_log(
        'roll_continuous_varattr',
        'Variation deltas: total_delta_normal=' || v_total_delta_normal ||
        ', total_delta_pnormal=' || v_total_delta_pnormal ||
        ', total_delta_pskew=' || v_total_delta_pskew
    );

    -- Compute effective min, max and normal.
    IF (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0) THEN
        v_eff_min    := (v_min + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew);
        v_eff_max    := (v_max + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew);
        v_eff_normal := (v_normal + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew);
    ELSE
        v_eff_min    := v_min + v_total_delta_normal;
        v_eff_max    := v_max + v_total_delta_normal;
        v_eff_normal := v_normal + v_total_delta_normal;
    END IF;

    PERFORM debug_log(
        'roll_continuous_varattr',
        'Effective values: eff_min=' || v_eff_min || ', eff_max=' || v_eff_max || ', eff_normal=' || v_eff_normal
    );

    IF v_eff_max < v_eff_min THEN
        v_tmp    := v_eff_min;
        v_eff_min := v_eff_max;
        v_eff_max := v_tmp;
    END IF;

    -- Generate a skewed random number.
    v_total_discrete_values := (v_eff_max - v_eff_min) * power(10, v_decimals) + 1;
    IF v_total_discrete_values < 1 THEN 
        v_total_discrete_values := 1; 
    END IF;
    v_random_uniform := random() * v_total_discrete_values;
    v_midpoint       := v_total_discrete_values / 2;
    v_skew_offset    := (-v_midpoint * COALESCE(v_percent_skewed, 0)) / 100;
    v_normal_offset  := v_eff_normal - ((v_eff_max - v_eff_min) / 2) - v_eff_min;
    IF v_percent_normal IS NULL OR v_percent_normal <= 0 THEN 
        v_percent_normal := 0; 
    END IF;
    v_degree_estimate          := -2.3 / LN((v_percent_normal / 100) + 0.000052) - 0.5;
    v_mult                     := floor(v_degree_estimate / 0.04);
    v_discrete_degree_estimate := v_mult * 0.04;
    v_cubic_degree_estimate    := 1 + 2 * v_discrete_degree_estimate;
    v_skewed                   := v_random_uniform - v_midpoint - v_skew_offset;
    v_distributed              := sign(v_skewed) * power(abs(v_skewed), v_cubic_degree_estimate);
    IF (v_total_discrete_values - 2 * v_skew_offset * sign(v_skewed)) = 0 THEN
        v_multiplier := 0;
    ELSE
        v_multiplier := ((v_eff_max - v_eff_min) * power(4, v_discrete_degree_estimate)) /
                        power((v_total_discrete_values - 2 * v_skew_offset * sign(v_skewed)), v_cubic_degree_estimate);
    END IF;
    v_avg    := (v_eff_min + v_eff_max) / 2;
    v_offset := ((-2 * v_normal_offset * v_multiplier * abs(v_distributed)) / (v_eff_max - v_eff_min))
                + v_normal_offset + v_avg;
    v_result := round((v_multiplier * v_distributed + v_offset)::numeric, v_decimals)::double precision;
    IF v_result < v_eff_min THEN
        v_clamped_result := v_eff_min;
    ELSIF v_result > v_eff_max THEN
        v_clamped_result := v_eff_max;
    ELSE
        v_clamped_result := v_result;
    END IF;

    PERFORM debug_log(
        'roll_continuous_varattr',
        'Computed v_clamped_result=' || v_clamped_result
    );

    -- Select the span matching the computed result.
    IF p_exclude_span_id IS NOT NULL AND p_exclude_span_id <> 0 THEN
        SELECT s.id,
               CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                    THEN (s.min_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                    ELSE (s.min_value + v_total_delta_normal)
               END,
               CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                    THEN (s.max_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                    ELSE (s.max_value + v_total_delta_normal)
               END
          INTO v_chosen_span_id, dummy_eff_min, dummy_eff_max
          FROM span s
          JOIN variant_attr_span vas ON vas.span_id = s.id
         WHERE s.attribute_id = v_attribute_id
           AND s.type = 'continuous'
           AND s.id <> p_exclude_span_id
           AND (p_variant_attr_variant_span_id IS NULL OR vas.id = p_variant_attr_variant_span_id)
           AND (CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                     THEN (s.min_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                     ELSE (s.min_value + v_total_delta_normal)
                END) <= v_clamped_result
           AND (CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                     THEN (s.max_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                     ELSE (s.max_value + v_total_delta_normal)
                END) > v_clamped_result
         LIMIT 1;
    ELSE
        SELECT s.id,
               CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                    THEN (s.min_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                    ELSE (s.min_value + v_total_delta_normal)
               END,
               CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                    THEN (s.max_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                    ELSE (s.max_value + v_total_delta_normal)
               END
          INTO v_chosen_span_id, dummy_eff_min, dummy_eff_max
          FROM span s
          JOIN variant_attr_span vas ON vas.span_id = s.id
         WHERE s.attribute_id = v_attribute_id
           AND s.type = 'continuous'
           AND (p_variant_attr_variant_span_id IS NULL OR vas.id = p_variant_attr_variant_span_id)
           AND (CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                     THEN (s.min_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                     ELSE (s.min_value + v_total_delta_normal)
                END) <= v_clamped_result
           AND (CASE WHEN (v_total_delta_pnormal <> 0 OR v_total_delta_pskew <> 0)
                     THEN (s.max_value + v_total_delta_normal) * (1 + v_total_delta_pnormal + v_total_delta_pskew)
                     ELSE (s.max_value + v_total_delta_normal)
                END) > v_clamped_result
         LIMIT 1;
    END IF;

    PERFORM debug_log(
        'roll_continuous_varattr',
        'Chosen continuous: span_id=' || COALESCE(v_chosen_span_id::text, 'NULL') ||
        ', numeric_value=' || COALESCE(v_clamped_result::text, 'NULL')
    );

    chosen_span_id := v_chosen_span_id;
    chosen_value   := v_clamped_result;
    PERFORM debug_log(
        'roll_continuous_varattr',
        'Exiting with chosen_span_id=' || chosen_span_id || ', chosen_value=' || chosen_value
    );
    RETURN NEXT;
    RETURN;
END;
$$;

--#endregion
--#region "generate_entity_state"

CREATE OR REPLACE PROCEDURE generate_entity_state(
    IN  p_entity_id                  INTEGER,
    IN  p_time                       DOUBLE PRECISION,
    IN  p_regenerate_entity_state_id INTEGER,
    OUT out_entity_state_id          INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_root_variant_id         INTEGER;
    v_entity_state_id         INTEGER;
    v_current_variant         INTEGER;
    cur_va_id               INTEGER;
    cur_attr_type           TEXT;
    v_variant_attr_span_id  INTEGER;
    v_existing_evav_id      INTEGER;
    v_existing_span_id      INTEGER;
    v_lock_count            INTEGER := 0;
    v_new_span_id           INTEGER;
    v_new_numeric           DOUBLE PRECISION;
    v_used_span_id          INTEGER;
    v_sub_variant_id        INTEGER;
    v_attr_counter          INTEGER := 0;
    rec                     RECORD;
BEGIN
    PERFORM debug_log(
        'generate_entity_state',
        'Start: p_entity_id=' || p_entity_id ||
        ', p_time=' || p_time ||
        ', p_regenerate_entity_state_id=' || COALESCE(p_regenerate_entity_state_id::text, 'NULL')
    );

    -- Get the root variant.
    SELECT variant_id
      INTO v_root_variant_id
      FROM entity
     WHERE id = p_entity_id;
    IF v_root_variant_id IS NULL THEN
       RAISE EXCEPTION 'No entity found with id=%', p_entity_id;
    END IF;
    PERFORM debug_log(
        'generate_entity_state',
        'Root variant id=' || v_root_variant_id
    );

    -- Use supplied state id (regeneration) or insert a new entity_state.
    IF p_regenerate_entity_state_id IS NOT NULL THEN
        v_entity_state_id := p_regenerate_entity_state_id;
    ELSE
        INSERT INTO entity_state(entity_id, "time")
        VALUES (p_entity_id, p_time)
        RETURNING id INTO v_entity_state_id;
    END IF;
    out_entity_state_id := v_entity_state_id;
    PERFORM debug_log(
        'generate_entity_state',
        'Entity state id=' || v_entity_state_id
    );

    -- Create temporary queue table.
    DROP TABLE IF EXISTS _variant_queue;
    CREATE TEMPORARY TABLE _variant_queue (
        variant_id INTEGER PRIMARY KEY
    ) ON COMMIT DROP;
    INSERT INTO _variant_queue (variant_id) VALUES (v_root_variant_id);
    PERFORM debug_log(
        'generate_entity_state',
        'Inserted root variant into queue.'
    );

    -- Create temporary table for variant attributes.
    DROP TABLE IF EXISTS _variant_attributes;
    CREATE TEMPORARY TABLE _variant_attributes (
        va_id    INTEGER,
        attr_type TEXT
    ) ON COMMIT DROP;

    -- Process the variant queue.
    LOOP
        SELECT variant_id
          INTO v_current_variant
          FROM _variant_queue
         LIMIT 1;
        EXIT WHEN NOT FOUND;
        PERFORM debug_log(
            'generate_entity_state',
            'Processing variant id=' || v_current_variant
        );
        DELETE FROM _variant_queue
         WHERE variant_id = v_current_variant;

        TRUNCATE _variant_attributes;
        INSERT INTO _variant_attributes (va_id, attr_type)
          SELECT va.id, a.type
            FROM variant_attribute va
            JOIN attribute a ON a.id = va.attribute_id
           WHERE va.variant_id = v_current_variant;

        v_attr_counter := 0;
        FOR rec IN
            SELECT va_id, attr_type FROM _variant_attributes
        LOOP
            cur_va_id    := rec.va_id;
            cur_attr_type:= rec.attr_type;
            v_attr_counter := v_attr_counter + 1;
            PERFORM debug_log(
                'generate_entity_state',
                'Processing attribute ' || v_attr_counter ||
                ': va_id=' || cur_va_id || ', attr_type=' || cur_attr_type
            );

            -- Get the variant_attr_span id; if none, it will remain null.
            SELECT id
              INTO v_variant_attr_span_id
              FROM variant_attr_span
             WHERE variant_attribute_id = cur_va_id
               AND variant_id = v_current_variant
             LIMIT 1;
            PERFORM debug_log(
                'generate_entity_state',
                'Variant_attr_span id for va_id=' || cur_va_id ||
                ' is ' || COALESCE(v_variant_attr_span_id::text, 'NULL')
            );

            IF p_regenerate_entity_state_id IS NOT NULL THEN
                SELECT id, span_id
                  INTO v_existing_evav_id, v_existing_span_id
                  FROM entity_varattr_value
                 WHERE entity_state_id = v_entity_state_id
                   AND variant_attribute_id = cur_va_id
                 LIMIT 1;
                PERFORM debug_log(
                    'generate_entity_state',
                    'Existing evav: id=' || COALESCE(v_existing_evav_id::text, 'NULL') ||
                    ', span_id=' || COALESCE(v_existing_span_id::text, 'NULL')
                );
            ELSE
                v_existing_evav_id := NULL;
                v_existing_span_id := NULL;
            END IF;

            IF p_regenerate_entity_state_id IS NOT NULL AND v_existing_evav_id IS NOT NULL THEN
                SELECT count(*) INTO v_lock_count
                  FROM evav_lock
                 WHERE locked_evav_id = v_existing_evav_id;
                PERFORM debug_log(
                    'generate_entity_state',
                    'Lock count for evav id=' || v_existing_evav_id ||
                    ' is ' || v_lock_count
                );
                IF v_lock_count > 0 THEN
                    v_used_span_id := v_existing_span_id;
                    PERFORM debug_log(
                        'generate_entity_state',
                        'Using locked span id=' || v_used_span_id
                    );
                ELSE
                    IF cur_attr_type = 'discrete' THEN
                        v_new_span_id := roll_discrete_varattr(cur_va_id, v_variant_attr_span_id, 0);
                        UPDATE entity_varattr_value
                           SET span_id = v_new_span_id
                         WHERE id = v_existing_evav_id;
                        v_used_span_id := v_new_span_id;
                        PERFORM debug_log(
                            'generate_entity_state',
                            'Updated discrete evav id=' || v_existing_evav_id ||
                            ' with new span id=' || v_new_span_id
                        );
                    ELSE
                        SELECT t.chosen_span_id, t.chosen_value
                          INTO v_new_span_id, v_new_numeric
                          FROM roll_continuous_varattr(cur_va_id, v_variant_attr_span_id, 0) t
                         LIMIT 1;
                        UPDATE entity_varattr_value
                           SET span_id = v_new_span_id,
                               numeric_value = v_new_numeric
                         WHERE id = v_existing_evav_id;
                        v_used_span_id := v_new_span_id;
                        PERFORM debug_log(
                            'generate_entity_state',
                            'Updated continuous evav id=' || v_existing_evav_id ||
                            ' with new span id=' || v_new_span_id ||
                            ' and numeric_value=' || v_new_numeric
                        );
                    END IF;
                END IF;
            ELSE
                IF cur_attr_type = 'discrete' THEN
                    v_new_span_id := roll_discrete_varattr(cur_va_id, v_variant_attr_span_id, 0);
                    INSERT INTO entity_varattr_value(
                        entity_state_id,
                        numeric_value,
                        span_id,
                        variant_attribute_id
                    ) VALUES (
                        v_entity_state_id,
                        NULL,
                        v_new_span_id,
                        cur_va_id
                    );
                    v_used_span_id := v_new_span_id;
                    PERFORM debug_log(
                        'generate_entity_state',
                        'Inserted discrete evav with span id=' || v_new_span_id
                    );
                ELSE
                    SELECT t.chosen_span_id, t.chosen_value
                      INTO v_new_span_id, v_new_numeric
                      FROM roll_continuous_varattr(cur_va_id, v_variant_attr_span_id, 0) t
                     LIMIT 1;
                    INSERT INTO entity_varattr_value(
                        entity_state_id,
                        numeric_value,
                        span_id,
                        variant_attribute_id
                    ) VALUES (
                        v_entity_state_id,
                        v_new_numeric,
                        v_new_span_id,
                        cur_va_id
                    );
                    v_used_span_id := v_new_span_id;
                    PERFORM debug_log(
                        'generate_entity_state',
                        'Inserted continuous evav with span id=' || v_new_span_id ||
                        ' and numeric_value=' || v_new_numeric
                    );
                END IF;
            END IF;

            -- If the chosen span activates a sub–variant, enqueue it.
            SELECT variant_id
              INTO v_sub_variant_id
              FROM variant_attr_span
             WHERE variant_attribute_id = cur_va_id
               AND id = v_used_span_id
             LIMIT 1;
            IF v_sub_variant_id IS NOT NULL AND v_sub_variant_id <> v_current_variant THEN
                INSERT INTO _variant_queue (variant_id)
                VALUES (v_sub_variant_id)
                ON CONFLICT (variant_id) DO NOTHING;
                PERFORM debug_log(
                    'generate_entity_state',
                    'Enqueued sub variant id=' || v_sub_variant_id ||
                    ' from va_id=' || cur_va_id
                );
            END IF;
        END LOOP;
    END LOOP;

    DROP TABLE IF EXISTS _variant_attributes;
    DROP TABLE IF EXISTS _variant_queue;
    PERFORM debug_log(
        'generate_entity_state',
        'Completed processing for entity state id=' || v_entity_state_id
    );
END;
$$;

--#endregion
--#region "generate_entity_states_in_range"

CREATE OR REPLACE PROCEDURE generate_entity_states_in_range(
    p_entity_id INTEGER,
    p_start_time INTEGER,
    p_end_time INTEGER,
    p_time_step INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    v_time INTEGER;
    v_entity_state_id INTEGER;
BEGIN
    FOR v_time IN
        SELECT generate_series(p_start_time, p_end_time, p_time_step)
    LOOP
        CALL generate_entity_state(p_entity_id, v_time, NULL, v_entity_state_id);
    END LOOP;
END;
$$;

--#endregion