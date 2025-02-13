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

--#region "add_discrete_attribute"

CREATE OR REPLACE PROCEDURE add_discrete_attribute(
    in_name       VARCHAR(255),
    OUT out_attr_id INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO attribute (name, type)
      VALUES (in_name, 'discrete')
      RETURNING id INTO out_attr_id;
END;
$$;

--#endregion
--#region "add_disc_span_to_attr"

CREATE OR REPLACE FUNCTION redistribute_unpinned_spans(
    p_attribute_id INTEGER,
    p_modified_span_id INTEGER,
    p_new_weight DOUBLE PRECISION,
    p_old_weight DOUBLE PRECISION
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_pinned_weight DOUBLE PRECISION;
    v_target         DOUBLE PRECISION;
BEGIN
    -- Compute the total weight of pinned discrete spans.
    SELECT COALESCE(SUM(weight), 0)
      INTO v_pinned_weight
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = true;
       
    -- The available weight for all unpinned spans.
    v_target := 1.0 - v_pinned_weight;
    
    -- If there’s only one unpinned span (v_target equals p_old_weight), then
    -- the new weight must equal the entire target.
    IF (v_target - p_old_weight) = 0 THEN
       IF p_new_weight <> v_target THEN
           RAISE EXCEPTION 'Cannot change weight; only one unpinned span exists and its weight must be %', v_target;
       END IF;
    END IF;
    
    -- Update all unpinned discrete spans:
    -- • The modified span gets the new weight.
    -- • All others are scaled proportionally.
    UPDATE span
       SET weight = CASE 
                      WHEN id = p_modified_span_id THEN p_new_weight
                      ELSE weight * ((v_target - p_new_weight) / (v_target - p_old_weight))
                    END
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = false;
END;
$$;


CREATE OR REPLACE PROCEDURE add_disc_span_to_attr(
    p_attribute_id INTEGER,
    p_label VARCHAR(255),
    OUT out_span_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_span_id     INTEGER;
    v_total_weight  DOUBLE PRECISION;
    v_pinned_weight DOUBLE PRECISION;
    v_target        DOUBLE PRECISION;
    v_count_old     INTEGER;
    candidate       DOUBLE PRECISION;
BEGIN
    -- Compute the total weight for all discrete spans for this attribute.
    SELECT COALESCE(SUM(weight), 0)
      INTO v_total_weight
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete';

    -- If no spans exist, simply insert the first span with weight 1.
    IF v_total_weight = 0 THEN
        INSERT INTO span(attribute_id, label, type, is_percentage_pinned, weight)
        VALUES (p_attribute_id, p_label, 'discrete', false, 1.0)
        RETURNING id INTO new_span_id;
        out_span_id := new_span_id;
        RETURN;
    END IF;
    
    -- Compute the total weight of pinned discrete spans.
    SELECT COALESCE(SUM(weight), 0)
      INTO v_pinned_weight
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = true;
    
    -- Calculate the available target weight for all unpinned spans.
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
    VALUES (p_attribute_id, p_label, 'discrete', false, 0.0)
    RETURNING id INTO new_span_id;

    out_span_id := new_span_id;
    
    -- Compute the candidate weight for the new span.
    candidate := v_target / (v_count_old + 1);
    
    -- Redistribute the weights among all unpinned spans
    PERFORM redistribute_unpinned_spans(p_attribute_id, new_span_id, candidate, 0);
END;
$$;


CREATE OR REPLACE PROCEDURE modify_disc_span_weight(
    p_span_id    INTEGER,
    p_new_weight DOUBLE PRECISION
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_attribute_id INTEGER;
    v_current_weight DOUBLE PRECISION;
    v_is_pinned    BOOLEAN;
    v_type         TEXT;
    v_pinned_weight DOUBLE PRECISION;
    v_target        DOUBLE PRECISION;
    v_other_sum     DOUBLE PRECISION;
BEGIN
    -- Get the current span's details.
    SELECT attribute_id, weight, is_percentage_pinned, type
      INTO v_attribute_id, v_current_weight, v_is_pinned, v_type
      FROM span
     WHERE id = p_span_id;
     
    -- Ensure the span exists, is of type 'discrete' and is not pinned.
    IF NOT FOUND OR v_type <> 'discrete' OR v_is_pinned THEN
       RAISE EXCEPTION 'Span % not found or not a modifiable discrete span', p_span_id;
    END IF;
    
    -- Compute the total pinned weight for this attribute.
    SELECT COALESCE(SUM(weight), 0)
      INTO v_pinned_weight
      FROM span
     WHERE attribute_id = v_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = true;
       
    v_target := 1.0 - v_pinned_weight;
    
    -- Validate the new weight is between 0 and the available target.
    IF p_new_weight < 0 OR p_new_weight > v_target THEN
       RAISE EXCEPTION 'Invalid new weight: % (must be between 0 and %)', p_new_weight, v_target;
    END IF;
    
    -- Compute the total weight for all other unpinned spans.
    SELECT COALESCE(SUM(weight), 0)
      INTO v_other_sum
      FROM span
     WHERE attribute_id = v_attribute_id
       AND type = 'discrete'
       AND is_percentage_pinned = false
       AND id <> p_span_id;
       
    IF v_other_sum = 0 THEN
       -- There is only one unpinned span. Its weight must equal the available target.
       IF p_new_weight <> v_target THEN
         RAISE EXCEPTION 'Only one unpinned span exists. Its weight must be %', v_target;
       ELSE
         UPDATE span SET weight = p_new_weight WHERE id = p_span_id;
       END IF;
    ELSE
       -- Use the helper function to redistribute weights.
       PERFORM redistribute_unpinned_spans(v_attribute_id, p_span_id, p_new_weight, v_current_weight);
    END IF;
END;
$$;

--#endregion
--#region "add_continuous_attribute"

CREATE OR REPLACE PROCEDURE add_continuous_attribute(
    p_name           VARCHAR(255),
    p_min_value      DOUBLE PRECISION,
    p_mode_value     DOUBLE PRECISION,
    p_max_value      DOUBLE PRECISION,
    p_concentration  DOUBLE PRECISION,
    p_skew           DOUBLE PRECISION,
    p_decimals       INTEGER,
    p_has_labels     BOOLEAN,
    p_has_value      BOOLEAN,
    p_units          VARCHAR(255),
    OUT p_attr_id    INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO attribute
      (name, type, decimals, has_labels, has_value, max_value, min_value,
       mode_value, concentration, skew, units)
    VALUES
      (p_name, 'continuous', p_decimals, p_has_labels, p_has_value, p_max_value,
       p_min_value, p_mode_value, p_concentration, p_skew, p_units)
    RETURNING id INTO p_attr_id;
END;
$$;

--#endregion
--#region "add_cont_span_to_attr"

CREATE OR REPLACE PROCEDURE add_cont_span_to_attr(
    p_attribute_id integer,
    p_label varchar(255),
    p_new_min double precision,
    p_new_max double precision,
    OUT out_span_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_attr_min double precision;
    v_attr_max double precision;
    v_count integer;
    v_first_id integer;
    v_first_min double precision;
    v_first_max double precision;
    v_last_id integer;
    v_last_min double precision;
    v_last_max double precision;
BEGIN
    -- Get attribute’s overall range (continuous only)
    SELECT min_value, max_value
      INTO v_attr_min, v_attr_max
      FROM attribute
     WHERE id = p_attribute_id
       AND type = 'continuous'
     LIMIT 1;
     
    IF v_attr_min IS NULL THEN
        RAISE EXCEPTION 'Attribute not found or not continuous';
    END IF;
    
    -- Validate requested span
    IF p_new_min < v_attr_min OR p_new_max > v_attr_max OR p_new_min >= p_new_max THEN
        RAISE EXCEPTION 'Invalid span range';
    END IF;
    
    -- If no continuous spans exist, insert one covering the full range
    SELECT COUNT(*) INTO v_count
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'continuous';
       
    IF v_count = 0 THEN
        INSERT INTO span(attribute_id, label, type, min_value, max_value)
        VALUES(p_attribute_id, p_label, 'continuous', v_attr_min, v_attr_max)
        RETURNING id INTO out_span_id;
        RETURN;
    END IF;
    
    -- Adjust overlapping spans: first overlapping span (ordered by min_value)
    SELECT id, min_value, max_value
      INTO v_first_id, v_first_min, v_first_max
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'continuous'
       AND max_value > p_new_min
       AND min_value < p_new_max
     ORDER BY min_value ASC
     LIMIT 1;
     
    IF v_first_min < p_new_min THEN
        UPDATE span SET max_value = p_new_min WHERE id = v_first_id;
    END IF;
    
    -- Adjust overlapping spans: last overlapping span (ordered by max_value)
    SELECT id, min_value, max_value
      INTO v_last_id, v_last_min, v_last_max
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'continuous'
       AND max_value > p_new_min
       AND min_value < p_new_max
     ORDER BY max_value DESC
     LIMIT 1;
     
    IF v_last_max > p_new_max THEN
        UPDATE span SET min_value = p_new_max WHERE id = v_last_id;
    END IF;
    
    -- Remove spans fully covered by the new span
    DELETE FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'continuous'
       AND min_value >= p_new_min
       AND max_value <= p_new_max;
       
    INSERT INTO span(attribute_id, label, type, min_value, max_value)
    VALUES(p_attribute_id, p_label, 'continuous', p_new_min, p_new_max)
    RETURNING id INTO out_span_id;;
END;
$$;

--#endregion
--#region "link_attr_to_variant"

CREATE OR REPLACE PROCEDURE link_attr_to_variant(
    p_variant_id   INTEGER,
    p_attribute_id INTEGER,
    p_name         VARCHAR,
    p_position     INTEGER,
    OUT out_varattr_id INTEGER
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
    VALUES (p_attribute_id, p_name, v_position, p_variant_id)
    RETURNING id INTO out_varattr_id;
END;
$$;

--#endregion
--#region "add_variant"

CREATE OR REPLACE PROCEDURE add_variant(
    in_variant_name VARCHAR,
    OUT out_variant_id INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO variant (name)
    VALUES (in_variant_name)
    RETURNING id INTO out_variant_id;
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

    RETURN v_span_id;
END;
$$;

--#endregion
--#region "roll_continuous_varattr"

CREATE OR REPLACE FUNCTION gamma_rng(shape double precision)
RETURNS double precision
LANGUAGE plpgsql
AS $$
DECLARE
    d double precision;
    c double precision;
    x double precision;
    v double precision;
    u double precision;
BEGIN
    IF shape < 1 THEN
        -- Use the transformation: Gamma(shape) = Gamma(shape+1)*U^(1/shape)
        RETURN gamma_rng(shape + 1) * power(random(), 1.0 / shape);
    END IF;
    d := shape - 1.0/3.0;
    c := 1.0 / sqrt(9.0 * d);
    LOOP
        -- Generate a standard normal via Box–Muller:
        x := sqrt(-2 * ln(random())) * cos(2 * 3.141592653589793 * random());
        v := 1 + c * x;
        IF v <= 0 THEN
            CONTINUE;
        END IF;
        v := v * v * v;
        u := random();
        IF u < 1 - 0.0331 * x * x * x * x THEN
            RETURN d * v;
        END IF;
        IF ln(u) < 0.5 * x * x + d * (1 - v + ln(v)) THEN
            RETURN d * v;
        END IF;
    END LOOP;
END;
$$;


-- using a fast Marsaglia–Tsang method
CREATE OR REPLACE FUNCTION weighted_random(
    min_val double precision,                   -- Minimum of desired range.
    max_val double precision,                   -- Maximum of desired range (must be > min_val).
    mode_val double precision,                  -- Desired mode (peak) in the same units.
    skew double precision DEFAULT 0,            -- Skew adjustment; between -1 and 1 only, 0 = no skew.
    concentration double precision DEFAULT 4    -- Concentration (k); should be >2 for a proper unimodal shape.
) RETURNS double precision
LANGUAGE plpgsql
AS $$
DECLARE
    m_norm      double precision;  -- Normalized desired mode in [0,1].
    alpha       double precision;
    beta        double precision;
    x_val       double precision;
    y_val       double precision;
    beta_sample double precision;
BEGIN
    IF min_val >= max_val THEN
        RAISE EXCEPTION 'min_val must be less than max_val';
    END IF;
    IF concentration < 0 THEN
        RAISE EXCEPTION 'concentration must be non-negative';
    END IF;
    IF concentration <= 2 THEN
        -- When concentration <= 2 the Beta isn't unimodal; fallback to uniform.
        RETURN min_val + random() * (max_val - min_val);
    END IF;

    -- Normalize the desired mode to [0,1].
    m_norm := (mode_val - min_val) / (max_val - min_val);

    -- Parameterize α and β so that (α-1)/(α+β-2) equals m_norm.
    alpha := m_norm * (concentration - 2) + 1;
    beta  := (1 - m_norm) * (concentration - 2) + 1;

    -- Apply skew correction if desired.
    IF skew <> 0 THEN
        alpha := alpha * (1 + skew);
        beta  := beta  * (1 - skew);
    END IF;

    -- Generate a Beta(α,β) random variable via the Gamma method.
    x_val := gamma_rng(alpha);
    y_val := gamma_rng(beta);
    beta_sample := x_val / (x_val + y_val);

    -- Scale the [0,1] Beta sample to [min_val, max_val].
    RETURN min_val + beta_sample * (max_val - min_val);
END;
$$;


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
    v_mode                      double precision;
    v_concentration             double precision;
    v_skew                      double precision;
    v_total_delta_mode          double precision := 0;
    v_total_delta_conc          double precision := 0;
    v_total_delta_skew          double precision := 0;
    v_eff_min                   double precision;
    v_eff_max                   double precision;
    v_eff_mode                  double precision;
    v_result                    double precision;
    v_clamped_result            double precision;
    v_chosen_span_id            integer;
    dummy_eff_min               double precision;
    dummy_eff_max               double precision;
BEGIN
    -- Retrieve attribute details.
    SELECT va.attribute_id,
           a.decimals,
           a.min_value,
           a.max_value,
           a.mode_value,
           a.concentration,
           a.skew
      INTO v_attribute_id, v_decimals, v_min, v_max, v_mode, v_concentration, v_skew
      FROM variant_attribute va
      JOIN attribute a ON a.id = va.attribute_id
     WHERE va.id = p_variant_attribute_id
     LIMIT 1;

    IF v_attribute_id IS NULL THEN
        RAISE EXCEPTION 'No matching attribute found';
    END IF;

    -- Sum variation deltas.
    SELECT COALESCE(SUM(vca.delta_mode), 0),
           COALESCE(SUM(vca.delta_conc), 0),
           COALESCE(SUM(vca.delta_skew), 0)
      INTO v_total_delta_mode, v_total_delta_conc, v_total_delta_skew
      FROM variation_continuous_attr vca
      JOIN (
            SELECT v.id
              FROM variation v
              JOIN vavspan_attr vav ON vav.id = v.to_modify_vavspan_attr_id
             WHERE vav.variant_attribute_id = p_variant_attribute_id
               AND vav.id = p_variant_attr_variant_span_id
               AND v.is_inactive = false
           ) av ON av.id = vca.variation_id;

    -- Compute effective min, max and mode.
    IF (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0) THEN
        v_eff_min    := (v_min + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew);
        v_eff_max    := (v_max + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew);
        v_eff_mode   := (v_mode + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew);
    ELSE
        v_eff_min    := v_min + v_total_delta_mode;
        v_eff_max    := v_max + v_total_delta_mode;
        v_eff_mode   := v_mode + v_total_delta_mode;
    END IF;

    IF v_eff_max < v_eff_min THEN
        -- Swap if needed.
        v_result    := v_eff_min;
        v_eff_min   := v_eff_max;
        v_eff_max   := v_result;
    END IF;

    -- Generate a weighted random value using the weighted_random function.
    v_result := weighted_random(
                   v_eff_min, 
                   v_eff_max, 
                   v_eff_mode, 
                   COALESCE(v_skew, 0),
                   COALESCE(v_concentration, 0)
               );
    v_result := round(v_result::numeric, v_decimals)::double precision;

    -- Clamp the result to the effective min and max.
    IF v_result < v_eff_min THEN
        v_clamped_result := v_eff_min;
    ELSIF v_result > v_eff_max THEN
        v_clamped_result := v_eff_max;
    ELSE
        v_clamped_result := v_result;
    END IF;

    -- Select the span matching the computed result.
    IF p_exclude_span_id IS NOT NULL AND p_exclude_span_id <> 0 THEN
        SELECT s.id,
               CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                    THEN (s.min_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                    ELSE (s.min_value + v_total_delta_mode)
               END,
               CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                    THEN (s.max_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                    ELSE (s.max_value + v_total_delta_mode)
               END
          INTO v_chosen_span_id, dummy_eff_min, dummy_eff_max
          FROM span s
          JOIN variant_attr_span vas ON vas.span_id = s.id
         WHERE s.attribute_id = v_attribute_id
           AND s.type = 'continuous'
           AND s.id <> p_exclude_span_id
           AND (p_variant_attr_variant_span_id IS NULL OR vas.id = p_variant_attr_variant_span_id)
           AND (CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                     THEN (s.min_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                     ELSE (s.min_value + v_total_delta_mode)
                END) <= v_clamped_result
           AND (CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                     THEN (s.max_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                     ELSE (s.max_value + v_total_delta_mode)
                END) > v_clamped_result
         LIMIT 1;
    ELSE
        SELECT s.id,
               CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                    THEN (s.min_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                    ELSE (s.min_value + v_total_delta_mode)
               END,
               CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                    THEN (s.max_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                    ELSE (s.max_value + v_total_delta_mode)
               END
          INTO v_chosen_span_id, dummy_eff_min, dummy_eff_max
          FROM span s
          JOIN variant_attr_span vas ON vas.span_id = s.id
         WHERE s.attribute_id = v_attribute_id
           AND s.type = 'continuous'
           AND (p_variant_attr_variant_span_id IS NULL OR vas.id = p_variant_attr_variant_span_id)
           AND (CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                     THEN (s.min_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                     ELSE (s.min_value + v_total_delta_mode)
                END) <= v_clamped_result
           AND (CASE WHEN (v_total_delta_conc <> 0 OR v_total_delta_skew <> 0)
                     THEN (s.max_value + v_total_delta_mode) * (1 + v_total_delta_conc + v_total_delta_skew)
                     ELSE (s.max_value + v_total_delta_mode)
                END) > v_clamped_result
         LIMIT 1;
    END IF;

    chosen_span_id := v_chosen_span_id;
    chosen_value   := v_clamped_result;
    RETURN NEXT;
    RETURN;
END;
$$;

--#endregion
--#region "generate_entity_state"

CREATE OR REPLACE PROCEDURE generate_entity_state(
    IN  p_entity_id                  INTEGER,
    IN  p_time                       DOUBLE PRECISION,
    IN  p_regenerate_entity_state_id INTEGER
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
    v_queue_id              INTEGER;  -- new variable for stack (LIFO) ordering
    rec                     RECORD;
BEGIN
    -- Get the root variant.
    SELECT variant_id
      INTO v_root_variant_id
      FROM entity
     WHERE id = p_entity_id;
    IF v_root_variant_id IS NULL THEN
       RAISE EXCEPTION 'No entity found with id=%', p_entity_id;
    END IF;

    -- Use supplied state id (regeneration) or insert a new entity_state.
    IF p_regenerate_entity_state_id IS NOT NULL THEN
        v_entity_state_id := p_regenerate_entity_state_id;
    ELSE
        INSERT INTO entity_state(entity_id, "time")
        VALUES (p_entity_id, p_time)
        RETURNING id INTO v_entity_state_id;
    END IF;

    -- Create temporary stack table for variant processing (depth-first).
    DROP TABLE IF EXISTS _variant_queue;
    CREATE TEMPORARY TABLE _variant_queue (
        queue_id serial PRIMARY KEY,
        variant_id INTEGER UNIQUE
    ) ON COMMIT DROP;
    INSERT INTO _variant_queue (variant_id) VALUES (v_root_variant_id);

    -- Create temporary table for variant attributes.
    DROP TABLE IF EXISTS _variant_attributes;
    CREATE TEMPORARY TABLE _variant_attributes (
        va_id    INTEGER,
        attr_type TEXT
    ) ON COMMIT DROP;

    -- Process the variant stack.
    LOOP
        SELECT queue_id, variant_id
          INTO v_queue_id, v_current_variant
          FROM _variant_queue
         ORDER BY queue_id DESC
         LIMIT 1;
        EXIT WHEN NOT FOUND;
        DELETE FROM _variant_queue
         WHERE queue_id = v_queue_id;

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
            cur_va_id     := rec.va_id;
            cur_attr_type := rec.attr_type;
            v_attr_counter := v_attr_counter + 1;

            -- Get the variant_attr_span id; if none, it will remain null.
            SELECT id
              INTO v_variant_attr_span_id
              FROM variant_attr_span
             WHERE variant_attribute_id = cur_va_id
               AND variant_id = v_current_variant
             LIMIT 1;

            IF p_regenerate_entity_state_id IS NOT NULL THEN
                SELECT id, span_id
                  INTO v_existing_evav_id, v_existing_span_id
                  FROM entity_varattr_value
                 WHERE entity_state_id = v_entity_state_id
                   AND variant_attribute_id = cur_va_id
                 LIMIT 1;
            ELSE
                v_existing_evav_id := NULL;
                v_existing_span_id := NULL;
            END IF;

            IF p_regenerate_entity_state_id IS NOT NULL AND v_existing_evav_id IS NOT NULL THEN
                SELECT count(*) INTO v_lock_count
                  FROM evav_lock
                 WHERE locked_evav_id = v_existing_evav_id;
                IF v_lock_count > 0 THEN
                    v_used_span_id := v_existing_span_id;
                ELSE
                    IF cur_attr_type = 'discrete' THEN
                        v_new_span_id := roll_discrete_varattr(cur_va_id, v_variant_attr_span_id, 0);
                        UPDATE entity_varattr_value
                           SET span_id = v_new_span_id
                         WHERE id = v_existing_evav_id;
                        v_used_span_id := v_new_span_id;
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
            END IF;
        END LOOP;
    END LOOP;

    DROP TABLE IF EXISTS _variant_attributes;
    DROP TABLE IF EXISTS _variant_queue;
END;
$$;


--#endregion
--#region "get_entity_state_details"

DROP TYPE IF EXISTS entity_state_details CASCADE;
CREATE TYPE entity_state_details AS (
  "Index"                   BIGINT,
  "Attribute"               VARCHAR(255),
  "Value"                   DOUBLE PRECISION,
  "Units"                   VARCHAR(255),
  "Label"                   VARCHAR(255),
  "Active Variations"       JSONB,
  "Caused Variant"          VARCHAR(255),
  "Locked"                  BOOLEAN
);

-- Main function: given an entity id, return one row per generated variant attribute value,
-- ordered by the effective causation order (i.e. the depth–first order in which
-- generate_entity_state processed them). The returned columns are:
--
--   state_time                -- the time stamp of the entity state
--   effective_causation_index -- the effective index (computed via depth–first traversal)
--   variant_attribute_name    -- the name of the variant attribute (from variant_attribute.name)
--   variant_name              -- the name of the variant that “owns” that attribute
--   numeric_value             -- the numeric value (if any, for continuous attributes)
--   span_label                -- the label of the chosen span (if any)
--   active_variations         -- a JSON object mapping “span addresses” (from ancestors that activated a variation)
--                               to arrays of variation details (including any sub–variant name activated)
--   sub_variant_name          -- if the chosen span activated a sub–variant, its name (else null)
--   is_locked                 -- whether this entity_varattr_value is locked
CREATE OR REPLACE FUNCTION get_entity_state_details(
    p_entity_id INT,
    p_time      DOUBLE PRECISION
)
RETURNS SETOF entity_state_details
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE 
  -- Compute a per–variant sibling order using causation_index.
  ordered_va AS (
    SELECT
      va.id AS variant_attribute_id,
      va.variant_id,
      va.attribute_id,
      va.name,
      va.causation_index,
      ROW_NUMBER() OVER (PARTITION BY va.variant_id ORDER BY va.causation_index) AS sibling_order
    FROM variant_attribute va
  ),
  --
  -- Build the processing tree while computing two “paths”:
  --
  --   * attribute_path – the flattened path using "/" as separator and not including the span label.
  --     For example: Human/Male/Irish/Hair Color
  --
  --   * json_full_address – same as attribute_path, except that if a span label exists it is appended
  --     with a colon (e.g. Human/Male/Irish/Hair Color:Red). This is used as the key in Active Variations.
  --
  ev_tree AS (
    -- Anchor: start with the entity state’s root variant.
    SELECT
      es."time" AS state_time,
      ev.id AS ev_id,
      ev.entity_state_id,
      ov.variant_attribute_id,
      v.name || '/' || ov.name AS attribute_path,
      v.name || '/' || ov.name || COALESCE(':' || s.label, '') AS json_full_address,
      v.id AS variant_id,
      v.name AS variant_name,
      ev.numeric_value,
      a.units,
      ev.span_id,
      s.label AS span_label,
      vas.variant_id AS activated_sub_variant,
      ARRAY[ ov.sibling_order ] AS proc_path
    FROM entity_state es
    JOIN entity e ON es.entity_id = e.id
    JOIN variant v ON e.variant_id = v.id
    JOIN entity_varattr_value ev ON ev.entity_state_id = es.id
    JOIN ordered_va ov ON ov.variant_attribute_id = ev.variant_attribute_id
    JOIN attribute a ON a.id = ov.attribute_id
    LEFT JOIN span s ON ev.span_id = s.id
    LEFT JOIN variant_attr_span vas 
           ON vas.id = ev.span_id
          AND vas.variant_attribute_id = ov.variant_attribute_id
    WHERE e.id = p_entity_id
      AND es."time" = p_time
      AND ov.variant_id = v.id

    UNION ALL

    -- Recursive step: for any attribute that activated a sub–variant,
    -- process the sub–variant’s attributes.
    SELECT
      parent.state_time,
      ev.id AS ev_id,
      ev.entity_state_id,
      ov.variant_attribute_id,
      parent.attribute_path || '/' || ov.name AS attribute_path,
      parent.json_full_address || '/' || ov.name || COALESCE(':' || s.label, '') AS json_full_address,
      v_child.id AS variant_id,
      v_child.name AS variant_name,
      ev.numeric_value,
      a.units,
      ev.span_id,
      s.label AS span_label,
      vas.variant_id AS activated_sub_variant,
      parent.proc_path || ov.sibling_order AS proc_path
    FROM ev_tree parent
    JOIN entity_varattr_value ev ON ev.entity_state_id = parent.entity_state_id
    JOIN ordered_va ov ON ov.variant_attribute_id = ev.variant_attribute_id
    JOIN variant v_child ON ov.variant_id = v_child.id
    JOIN attribute a ON a.id = ov.attribute_id
    LEFT JOIN span s ON ev.span_id = s.id
    LEFT JOIN variant_attr_span vas 
           ON vas.id = ev.span_id
          AND vas.variant_attribute_id = ov.variant_attribute_id
    WHERE parent.activated_sub_variant IS NOT NULL
      AND ov.variant_id = parent.activated_sub_variant
  ),
  --
  -- Index the tree by ordering lexicographically on proc_path.
  ev_indexed AS (
    SELECT ev.*,
           row_number() OVER (ORDER BY ev.proc_path) AS effective_causation_index
    FROM ev_tree ev
  )
  --
  -- Final select: return one row per processed attribute value.
  SELECT 
    ev.effective_causation_index::bigint AS "Index",
    ev.attribute_path::varchar(255) AS "Attribute",
    ev.numeric_value::double precision AS "Value",
    ev.units::varchar(255) AS "Units",
    ev.span_label::varchar(255) AS "Label",
    (
      SELECT COALESCE(
        jsonb_object_agg(anc_variations.json_full_address, anc_variations.variations_array),
        '{}'::jsonb
      )
      FROM (
        SELECT
          anc.json_full_address,
          jsonb_agg(
            jsonb_build_object(
              'variation_id', v.id,
              'is_inactive', v.is_inactive,
              'variation_continuous_attr', CASE WHEN vca.id IS NOT NULL THEN to_jsonb(vca) ELSE NULL END,
              'variation_activated_span', CASE WHEN vas2.id IS NOT NULL THEN to_jsonb(vas2) ELSE NULL END,
              'variation_delta_weight', CASE WHEN vd.id IS NOT NULL THEN to_jsonb(vd) ELSE NULL END,
              'variation_inactive_span', CASE WHEN vi.id IS NOT NULL THEN to_jsonb(vi) ELSE NULL END
            )
          ) AS variations_array
        FROM ev_indexed anc
        JOIN variation v ON v.activating_span_id = anc.span_id
        LEFT JOIN variation_continuous_attr vca ON vca.variation_id = v.id
        LEFT JOIN variation_activated_span vas2 ON vas2.variation_id = v.id
        LEFT JOIN variation_delta_weight vd ON vd.variation_id = v.id
        LEFT JOIN variation_inactive_span vi ON vi.variation_id = v.id
        WHERE anc.effective_causation_index < ev.effective_causation_index
          AND anc.span_id IS NOT NULL
        GROUP BY anc.json_full_address
      ) anc_variations
    ) AS "Active Variations",
    (
      CASE 
        WHEN ev.activated_sub_variant IS NOT NULL THEN
           (SELECT v2.name FROM variant v2 WHERE v2.id = ev.activated_sub_variant)
        ELSE NULL
      END
    )::varchar(255) AS "Caused Variant",
    EXISTS (
      SELECT 1 
      FROM evav_lock 
      WHERE locked_evav_id = ev.ev_id
    ) AS "Locked"
  FROM ev_indexed ev
  ORDER BY ev.effective_causation_index;
END;
$$;

--#endregion
--#region "generate_entity_group"

CREATE OR REPLACE PROCEDURE generate_entity_group(
    p_variant_id           INTEGER,
    p_group_name           VARCHAR,
    p_entity_name_template VARCHAR,
    p_num_entities         INTEGER,
    OUT out_entity_group_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_entity_group_id  INTEGER;
    v_entity_id        INTEGER;
    v_entity_state_id  INTEGER;
    v_idx              INTEGER;
    v_entity_name      VARCHAR(255);
BEGIN
    INSERT INTO entity_group (name)
    VALUES (p_group_name)
    RETURNING id INTO v_entity_group_id;

    out_entity_group_id := v_entity_group_id;

    FOR v_idx IN 1..p_num_entities LOOP
        v_entity_name := format(p_entity_name_template, v_idx);

        INSERT INTO entity (variant_id, name)
        VALUES (p_variant_id, v_entity_name)
        RETURNING id INTO v_entity_id;

        INSERT INTO entity_group_link (entity_id, entity_group_id)
        VALUES (v_entity_id, v_entity_group_id);

        CALL generate_entity_state(v_entity_id, 0, NULL);
    END LOOP;
END;
$$;

--#endregion
--#region "get_entity_group_state_details"

CREATE OR REPLACE FUNCTION get_entity_group_state_details(
    p_entity_group_id INT
)
RETURNS TEXT
LANGUAGE sql
AS $$
  SELECT jsonb_pretty(
           COALESCE(
             jsonb_object_agg(e.name, details),
             '{}'::jsonb
           )
         )
  FROM (
    SELECT e.name,
           (
             SELECT jsonb_agg(
                      jsonb_strip_nulls(
                        jsonb_build_object(
                          'Attribute', d."Attribute",
                          'Value', CASE 
                                     WHEN d."Value" IS NOT NULL 
                                       THEN CASE 
                                              WHEN d."Units" IS NOT NULL 
                                                THEN d."Value"::text || ' ' || d."Units"
                                              ELSE d."Value"::text
                                            END
                                     ELSE NULL
                                   END,
                          'Label', d."Label",
                          'Active Variations', CASE 
                                                 WHEN d."Active Variations" = '{}'::jsonb THEN NULL 
                                                 ELSE d."Active Variations" 
                                               END,
                          'Caused Variant', d."Caused Variant",
                          'Locked', CASE WHEN d."Locked" THEN d."Locked" ELSE NULL END
                        )
                      )
                    )
             FROM get_entity_state_details(e.id, 0) AS d
           ) AS details
    FROM entity e
    JOIN entity_group_link egl ON e.id = egl.entity_id
    WHERE egl.entity_group_id = p_entity_group_id
  ) e;
$$;

--#endregion

--#region "set_variant_attr_span"

CREATE OR REPLACE PROCEDURE set_variant_attr_span(
    p_variant_id INT,
    p_variant_attribute_id INT,
    p_span_id INT,
    OUT new_variant_attr_span_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO variant_attr_span(variant_id, variant_attribute_id, span_id)
  VALUES (p_variant_id, p_variant_attribute_id, p_span_id)
  RETURNING id INTO new_variant_attr_span_id;
END;
$$;

--#endregion
--#region "add_variation"

CREATE OR REPLACE PROCEDURE add_variation(
    p_activating_span_id INT,
    p_activating_variant_attr_span_id INT,
    p_activating_variant_attribute_id INT,
    p_to_modify_variant_attr_span_id INT,
    p_to_modify_variant_attribute_id INT,
    OUT new_variation_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_to_modify_vavspan_attr_id INT;
    v_activating_vavspan_attr_id INT;
BEGIN
    -- Try to get an existing vavspan_attr row for the "to modify" attribute.
    SELECT id INTO v_to_modify_vavspan_attr_id
      FROM vavspan_attr
     WHERE variant_attribute_id = p_to_modify_variant_attribute_id
       AND variant_attr_span_id = p_to_modify_variant_attr_span_id
     LIMIT 1;

    -- If none exists, insert one.
    IF v_to_modify_vavspan_attr_id IS NULL THEN
        INSERT INTO vavspan_attr (variant_attribute_id, variant_attr_span_id)
        VALUES (p_to_modify_variant_attribute_id, p_to_modify_variant_attr_span_id)
        RETURNING id INTO v_to_modify_vavspan_attr_id;
    END IF;

    -- Try to get an existing vavspan_attr row for the "activating" attribute.
    SELECT id INTO v_activating_vavspan_attr_id
      FROM vavspan_attr
     WHERE variant_attribute_id = p_activating_variant_attribute_id
       AND variant_attr_span_id = p_activating_variant_attr_span_id
     LIMIT 1;

    -- If none exists, insert one.
    IF v_activating_vavspan_attr_id IS NULL THEN
        INSERT INTO vavspan_attr (variant_attribute_id, variant_attr_span_id)
        VALUES (p_activating_variant_attribute_id, p_activating_variant_attr_span_id)
        RETURNING id INTO v_activating_vavspan_attr_id;
    END IF;

    -- Insert the new variation using the determined vavspan_attr IDs.
    INSERT INTO variation(
        activating_span_id, 
        to_modify_vavspan_attr_id, 
        activating_vavspan_attr_id
    )
    VALUES (
        p_activating_span_id, 
        v_to_modify_vavspan_attr_id, 
        v_activating_vavspan_attr_id
    )
    RETURNING id INTO new_variation_id;
END;
$$;

--#endregion
--#region "set_continuous_variation_span"

CREATE OR REPLACE PROCEDURE set_continuous_variation_span(
    p_variation_id INT,
    p_delta_mode DOUBLE PRECISION,
    p_delta_conc DOUBLE PRECISION,
    p_delta_skew DOUBLE PRECISION,
    OUT new_variation_cont_attr_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO variation_continuous_attr(variation_id, delta_mode, delta_conc, delta_skew)
  VALUES (p_variation_id, p_delta_mode, p_delta_conc, p_delta_skew)
  RETURNING id INTO new_variation_cont_attr_id;
END;
$$;

--#endregion
--#region "set_span_activating_span"

CREATE OR REPLACE PROCEDURE set_span_activating_span(
    p_variation_id INT,
    p_span_id INT,
    OUT new_variation_activated_span_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO variation_activated_span(variation_id, span_id)
  VALUES (p_variation_id, p_span_id)
  RETURNING id INTO new_variation_activated_span_id;
END;
$$;

--#endregion
--#region "set_delta_weight_span"

CREATE OR REPLACE PROCEDURE set_delta_weight_span(
    p_variation_id INT,
    p_span_id INT,
    p_delta_weight DOUBLE PRECISION,
    OUT new_variation_delta_weight_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO variation_delta_weight(variation_id, span_id, delta_weight)
  VALUES (p_variation_id, p_span_id, p_delta_weight)
  RETURNING id INTO new_variation_delta_weight_id;
END;
$$;

--#endregion
--#region "set_span_disabling_span"

CREATE OR REPLACE PROCEDURE set_span_disabling_span(
    p_variation_id INT,
    p_span_id INT,
    OUT new_variation_inactive_span_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO variation_inactive_span(variation_id, span_id)
  VALUES (p_variation_id, p_span_id)
  RETURNING id INTO new_variation_inactive_span_id;
END;
$$;

--#endregion
--#region "link_vavspan_attr"

CREATE OR REPLACE PROCEDURE link_vavspan_attr(
    p_variant_attribute_id INT,
    p_variant_attr_span_id INT,
    OUT new_vavspan_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO vavspan_attr(variant_attribute_id, variant_attr_span_id)
  VALUES (p_variant_attribute_id, p_variant_attr_span_id)
  RETURNING id INTO new_vavspan_id;
END;
$$;

--#endregion
