CREATE TABLE `attribute` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `type` ENUM('discrete', 'continuous') NOT NULL,
    `decimals` INT NULL,
    `has_labels` BOOLEAN NULL,
    `has_value` BOOLEAN NULL,
    `max_value` DOUBLE NULL,
    `min_value` DOUBLE NULL,
    `normal_value` DOUBLE NULL,
    `percent_normal` DOUBLE NULL,
    `percent_skewed` DOUBLE NULL,
    `units` VARCHAR(255) NULL,
    PRIMARY KEY (`id`),
    CHECK (
        max_value IS NULL
        OR min_value IS NULL
        OR max_value >= min_value
    ),
    CHECK (
        (
            type = 'discrete'
            AND decimals IS NULL
            AND has_labels IS NULL
            AND has_value IS NULL
            AND max_value IS NULL
            AND min_value IS NULL
            AND normal_value IS NULL
            AND percent_normal IS NULL
            AND percent_pinned IS NULL
            AND percent_skewed IS NULL
            AND units IS NULL
        )
        OR (
            type = 'continuous'
            AND decimals IS NOT NULL
            AND has_labels IS NOT NULL
            AND has_value IS NOT NULL
            AND max_value IS NOT NULL
            AND min_value IS NOT NULL
            AND normal_value IS NOT NULL
            AND percent_normal IS NOT NULL
            AND percent_pinned IS NOT NULL
            AND percent_skewed IS NOT NULL
        )
    )
);
CREATE TABLE `span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `attribute_id` INT UNSIGNED NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `type` ENUM('discrete', 'continuous') NOT NULL,
    `is_percentage_pinned` BOOLEAN NULL,
    `weight` INT NULL,
    `max_value` DOUBLE NULL,
    `min_value` DOUBLE NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_spans_attr` FOREIGN KEY (`attribute_id`) REFERENCES `attribute` (`id`) ON DELETE CASCADE,
    CHECK (
        max_value IS NULL
        OR min_value IS NULL
        OR max_value >= min_value
    ),
    CHECK (
        (
            type = 'discrete'
            AND is_percentage_pinned IS NOT NULL
            AND weight IS NOT NULL
            AND max_value IS NULL
            AND min_value IS NULL
        )
        OR (
            type = 'continuous'
            AND is_percentage_pinned IS NULL
            AND weight IS NULL
            AND max_value IS NOT NULL
            AND min_value IS NOT NULL
        )
    )
);
CREATE TABLE `variant` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL
);
CREATE TABLE `variant_attribute` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `attribute_id` INT UNSIGNED NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `causation_index` INT NOT NULL,
    `variant_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_variant_attrs_attr` FOREIGN KEY (`attribute_id`) REFERENCES `attribute` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_variant_attrs_variant` FOREIGN KEY (`variant_id`) REFERENCES `variant` (`id`) ON DELETE CASCADE
);
CREATE TABLE `variant_attr_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    `variant_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_varattr_spans_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_varattr_spans_varattr` FOREIGN KEY (`variant_attribute_id`) REFERENCES `variant_attribute` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_varattr_spans_variant` FOREIGN KEY (`variant_id`) REFERENCES `variant` (`id`) ON DELETE CASCADE
); -- short for variant_attribute_variant_span
CREATE TABLE `vavspan_attr` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    `variant_attr_span_id` INT UNSIGNED,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_vavspan_attrs_va` FOREIGN KEY (`variant_attribute_id`) REFERENCES `variant_attribute` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_vavspan_attrs_vas` FOREIGN KEY (`variant_attr_span_id`) REFERENCES `variant_attr_span` (`id`) ON DELETE CASCADE
); -- short for variant_attribute_variant_span_variant_attribute
CREATE TABLE `variation` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `activating_span_id` INT UNSIGNED NOT NULL,
    `to_modify_vavspan_attr_id` INT UNSIGNED NOT NULL,
    `activating_vavspan_attr_id` INT UNSIGNED NOT NULL,
    `is_inactive` BOOLEAN NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_variations_span` FOREIGN KEY (`activating_span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_variations_vavspan_to_modify` FOREIGN KEY (`to_modify_vavspan_attr_id`) REFERENCES `vavspan_attr` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_variations_vavspan_activating` FOREIGN KEY (`activating_vavspan_attr_id`) REFERENCES `vavspan_attr` (`id`) ON DELETE CASCADE
);
CREATE TABLE `variation_continuous_attr` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variation_id` INT UNSIGNED NOT NULL,
    `delta_normal` DOUBLE NOT NULL,
    `delta_percent_normal` DOUBLE NOT NULL,
    `delta_percent_skewed` DOUBLE NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_continuous_attr_var` FOREIGN KEY (`variation_id`) REFERENCES `variation` (`id`) ON DELETE CASCADE
); -- short for variation_on_continuous_attribute
CREATE TABLE `variation_activated_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_activated_spans_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_var_activated_spans_var` FOREIGN KEY (`variation_id`) REFERENCES `variation` (`id`) ON DELETE CASCADE
);
CREATE TABLE `variation_delta_weight` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `delta_weight` DOUBLE NOT NULL,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_delta_weights_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_var_delta_weights_var` FOREIGN KEY (`variation_id`) REFERENCES `variation` (`id`) ON DELETE CASCADE
);
CREATE TABLE `variation_inactive_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_inactive_spans_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_var_inactive_spans_var` FOREIGN KEY (`variation_id`) REFERENCES `variation` (`id`) ON DELETE CASCADE
);
CREATE TABLE `entity` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variant_id` INT UNSIGNED NOT NULL,
    `commit_hash` CHAR(32) NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_entities_variant` FOREIGN KEY (`variant_id`) REFERENCES `variant` (`id`) ON DELETE CASCADE
);
CREATE TABLE `entity_state` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `entity_id` INT UNSIGNED NOT NULL,
    `time` DOUBLE NOT NULL UNIQUE,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_entity` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`id`) ON DELETE CASCADE
);
CREATE TABLE `entity_varattr_value` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `entity_state_id` INT UNSIGNED NOT NULL,
    `numeric_value` DOUBLE,
    `span_id` INT UNSIGNED,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_evav_entity_state` FOREIGN KEY (`entity_state_id`) REFERENCES `entity_state` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_evav_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_evav_variant_attr` FOREIGN KEY (`variant_attribute_id`) REFERENCES `variant_attribute` (`id`) ON DELETE CASCADE
); -- short for entity_variant_attribute_value

CREATE VIEW v_variant_attributes AS
SELECT 
    va.id AS variant_attribute_id,
    va.variant_id,
    va.causation_index,
    a.type AS attribute_type,
    a.decimals,
    a.has_labels,
    a.has_value,
    a.max_value,
    a.min_value,
    a.normal_value,
    a.percent_normal,
    a.percent_skewed,
    a.units
FROM variant_attribute va
JOIN attribute a ON va.attribute_id = a.id;

CREATE VIEW v_variant_attr_spans AS
SELECT 
    vas.id AS variant_attr_span_id,
    vas.variant_attribute_id,
    vas.variant_id,
    s.id AS span_id,
    s.label,
    s.type AS span_type,
    s.is_percentage_pinned,
    s.weight,
    s.max_value,
    s.min_value
FROM variant_attr_span vas
JOIN span s ON vas.span_id = s.id;

CREATE VIEW v_entity_variant_attributes AS
SELECT 
    e.id AS entity_id,
    e.variant_id,
    va.variant_attribute_id,
    va.causation_index,
    va.attribute_type,
    vas.variant_attr_span_id,
    s.span_id,
    s.label,
    s.span_type
FROM entity e
JOIN variant_attribute va ON e.variant_id = va.variant_id
JOIN v_variant_attr_spans vas ON va.id = vas.variant_attribute_id;

CREATE VIEW v_variations_details AS
SELECT 
    v.id AS variation_id,
    v.activating_span_id,
    v.to_modify_vavspan_attr_id,
    v.activating_vavspan_attr_id,
    v.is_inactive,
    vca.delta_normal,
    vca.delta_percent_normal,
    vca.delta_percent_skewed
FROM variation v
LEFT JOIN variation_continuous_attr vca ON v.id = vca.variation_id;

CREATE VIEW v_vavspan_attrs AS
SELECT 
  id AS vavspan_attr_id,
  variant_attribute_id,
  variant_attr_span_id
FROM vavspan_attr;







DELIMITER $$
CREATE PROCEDURE get_page_from_table(
    IN  p_base_query        TEXT,        -- Base query with a placeholder {TABLE}; e.g. "SELECT * FROM {TABLE}"
    IN  p_table_name        VARCHAR(64), -- Table name (without AS OF clause)
    IN  p_commitHash        VARCHAR(64), -- Optional commit hash for Dolt AS OF queries
    IN  p_filter            TEXT,        -- Optional filter condition (e.g. "status = 'active'")
    
    -- Sorting parameters for primary sort column:
    IN  p_sort_column1      VARCHAR(64), -- Primary sort column name
    IN  p_sort_direction1   VARCHAR(4),  -- Sort direction for primary column: 'ASC' or 'DESC'
    IN  p_cursor_value1     TEXT,        -- Cursor value for primary sort column
    
    -- Optional secondary sort column for composite ordering:
    IN  p_sort_column2      VARCHAR(64), -- Secondary sort column name (or NULL/empty if not used)
    IN  p_sort_direction2   VARCHAR(4),  -- Sort direction for secondary column: 'ASC' or 'DESC'
    IN  p_cursor_value2     TEXT,        -- Cursor value for secondary sort column
    
    IN  p_direction         VARCHAR(6),  -- Overall paging direction: 'after' or 'before'
    IN  p_limit             INT          -- Maximum number of rows to return
)
BEGIN
    -- Variables to hold parts of the dynamic query:
    DECLARE v_table_ref               VARCHAR(200);
    DECLARE v_final_base_query        TEXT;
    DECLARE v_filter_clause           TEXT;
    DECLARE v_paging_condition        TEXT;
    DECLARE v_order_clause            TEXT;
    DECLARE v_reversed_order_clause   TEXT;
    DECLARE v_full_query              TEXT;
    DECLARE v_is_composite            BOOLEAN DEFAULT FALSE;
    DECLARE op1                       VARCHAR(3);
    DECLARE op2                       VARCHAR(3);

    -----------------------------------------------------------------------------
    -- A. Build the dynamic table reference (with Dolt AS OF syntax if needed)
    -----------------------------------------------------------------------------
    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
        SET v_table_ref = CONCAT(p_table_name, ' AS OF ''', p_commitHash, '''');
    ELSE
        SET v_table_ref = p_table_name;
    END IF;

    -- Replace the placeholder {TABLE} in the base query.
    SET v_final_base_query = REPLACE(p_base_query, '{TABLE}', v_table_ref);

    -----------------------------------------------------------------------------
    -- B. Build the filtering clause (if any)
    -----------------------------------------------------------------------------
    IF p_filter IS NOT NULL AND TRIM(p_filter) <> '' THEN
        SET v_filter_clause = CONCAT('(', p_filter, ')');
    ELSE
        SET v_filter_clause = '';
    END IF;

    -----------------------------------------------------------------------------
    -- C. Determine if composite (two‑column) ordering is in use.
    -----------------------------------------------------------------------------
    IF p_sort_column2 IS NOT NULL AND TRIM(p_sort_column2) <> '' THEN
        SET v_is_composite = TRUE;
    END IF;

    -----------------------------------------------------------------------------
    -- D. Determine comparison operators for the “cursor” condition.
    --    For a column sorted ASC:
    --      - when paging “after” we want: col > cursor
    --      - when paging “before” we want: col < cursor
    --    For a column sorted DESC, the operators are reversed.
    -----------------------------------------------------------------------------
    IF p_direction = 'after' THEN
        IF UPPER(p_sort_direction1) = 'ASC' THEN
            SET op1 = '>';
        ELSE
            SET op1 = '<';
        END IF;
    ELSE
        -- p_direction = 'before'
        IF UPPER(p_sort_direction1) = 'ASC' THEN
            SET op1 = '<';
        ELSE
            SET op1 = '>';
        END IF;
    END IF;

    IF v_is_composite THEN
        IF p_direction = 'after' THEN
            IF UPPER(p_sort_direction2) = 'ASC' THEN
                SET op2 = '>';
            ELSE
                SET op2 = '<';
            END IF;
        ELSE
            IF UPPER(p_sort_direction2) = 'ASC' THEN
                SET op2 = '<';
            ELSE
                SET op2 = '>';
            END IF;
        END IF;
    END IF;

    -----------------------------------------------------------------------------
    -- E. Build the paging (cursor) condition.
    --
    -- For a single sort column:
    --   (p_sort_column1 op1 ?)
    --
    -- For composite (two‑column) ordering, we use a lexicographical condition:
    --   ( (p_sort_column1 op1 ?)
    --     OR (p_sort_column1 = ? AND p_sort_column2 op2 ?) )
    -----------------------------------------------------------------------------
    IF v_is_composite THEN
        SET v_paging_condition = CONCAT(
            '(',
                p_sort_column1, ' ', op1, ' ? ',
                'OR (', p_sort_column1, ' = ? AND ', p_sort_column2, ' ', op2, ' ?)',
            ')'
        );
    ELSE
        SET v_paging_condition = CONCAT('(', p_sort_column1, ' ', op1, ' ?)');
    END IF;

    -----------------------------------------------------------------------------
    -- F. Build the ORDER BY clause.
    --
    -- For "after" paging, we use the natural ordering.
    -- For "before" paging we build an inner query that orders in the reverse order,
    -- then wrap it so that the final output is in the natural order.
    -----------------------------------------------------------------------------
    IF p_direction = 'after' THEN
        IF v_is_composite THEN
            SET v_order_clause = CONCAT(
                'ORDER BY ', p_sort_column1, ' ', p_sort_direction1, ', ',
                              p_sort_column2, ' ', p_sort_direction2
            );
            -- Compute the reverse ordering for "before" paging.
            SET v_reversed_order_clause = CONCAT(
                'ORDER BY ', 
                    p_sort_column1, ' ', IF(UPPER(p_sort_direction1) = 'ASC', 'DESC', 'ASC'),
                ', ',
                    p_sort_column2, ' ', IF(UPPER(p_sort_direction2) = 'ASC', 'DESC', 'ASC')
            );
        ELSE
            SET v_order_clause = CONCAT(
                'ORDER BY ', p_sort_column1, ' ', p_sort_direction1
            );
            SET v_reversed_order_clause = CONCAT(
                'ORDER BY ', p_sort_column1, ' ', IF(UPPER(p_sort_direction1) = 'ASC', 'DESC', 'ASC')
            );
        END IF;
    ELSE
        -- For "before" paging we need both a reversed ordering (in the inner query)
        -- and the natural ordering in the outer query.
        IF v_is_composite THEN
            SET v_order_clause = CONCAT(
                'ORDER BY ', p_sort_column1, ' ', p_sort_direction1, ', ',
                              p_sort_column2, ' ', p_sort_direction2
            );
            SET v_reversed_order_clause = CONCAT(
                'ORDER BY ', 
                    p_sort_column1, ' ', IF(UPPER(p_sort_direction1) = 'ASC', 'DESC', 'ASC'),
                ', ',
                    p_sort_column2, ' ', IF(UPPER(p_sort_direction2) = 'ASC', 'DESC', 'ASC')
            );
        ELSE
            SET v_order_clause = CONCAT(
                'ORDER BY ', p_sort_column1, ' ', p_sort_direction1
            );
            SET v_reversed_order_clause = CONCAT(
                'ORDER BY ', p_sort_column1, ' ', IF(UPPER(p_sort_direction1) = 'ASC', 'DESC', 'ASC')
            );
        END IF;
    END IF;

    -----------------------------------------------------------------------------
    -- G. Combine the filter and paging conditions into the WHERE clause.
    -----------------------------------------------------------------------------
    IF v_filter_clause <> '' THEN
        SET v_filter_clause = CONCAT('WHERE ', v_filter_clause, ' AND ', v_paging_condition);
    ELSE
        SET v_filter_clause = CONCAT('WHERE ', v_paging_condition);
    END IF;

    -----------------------------------------------------------------------------
    -- H. Build the final dynamic query.
    -----------------------------------------------------------------------------
    IF p_direction = 'after' THEN
        SET v_full_query = CONCAT(
            v_final_base_query, ' ',
            v_filter_clause, ' ',
            v_order_clause, ' ',
            'LIMIT ?'
        );
    ELSE
        SET v_full_query = CONCAT(
            'SELECT * FROM (',
                v_final_base_query, ' ',
                v_filter_clause, ' ',
                v_reversed_order_clause, ' ',
                'LIMIT ?',
            ') AS t ',
            v_order_clause
        );
    END IF;

    -- (Optional debugging: you can uncomment the following line to see the built query.)
    -- SELECT v_full_query;

    -----------------------------------------------------------------------------
    -- I. Prepare and execute the dynamic SQL.
    --
    -- For a composite ordering the paging condition has three placeholders:
    --    1. for p_cursor_value1,
    --    2. again for p_cursor_value1 (in the equality test),
    --    3. and for p_cursor_value2.
    -- For a single column ordering there is one placeholder.
    -- In either case a placeholder is needed for the LIMIT.
    -----------------------------------------------------------------------------
    IF v_is_composite THEN
        PREPARE stmt FROM v_full_query;
        EXECUTE stmt USING p_cursor_value1, p_cursor_value1, p_cursor_value2, p_limit;
        DEALLOCATE PREPARE stmt;
    ELSE
        PREPARE stmt FROM v_full_query;
        EXECUTE stmt USING p_cursor_value1, p_limit;
        DEALLOCATE PREPARE stmt;
    END IF;
END $$
DELIMITER ;



DELIMITER $$
CREATE PROCEDURE get_variation_options_page (
    IN  p_vavs_id INT,
    IN  p_va_id INT,
    IN  p_variant_id INT,
    IN  p_causation_index INT,
    IN  p_limit INT,
    IN  p_direction VARCHAR(6),    -- 'after' or 'before'
    IN  p_commitHash VARCHAR(64)     -- for Dolt: optional commit hash
)
BEGIN
    -------------------------------------------------------------------
    -- A: Build “table references” depending on p_commitHash
    -------------------------------------------------------------------
    DECLARE v_table_va      VARCHAR(200);
    DECLARE v_table_vas     VARCHAR(200);
    DECLARE v_table_vavspan VARCHAR(200);

    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
        SET v_table_va      = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
        SET v_table_vas     = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
        SET v_table_vavspan = CONCAT('vavspan_attr AS OF ''', p_commitHash, '''');
    ELSE
        SET v_table_va      = 'variant_attribute';
        SET v_table_vas     = 'variant_attr_span';
        SET v_table_vavspan = 'vavspan_attr';
    END IF;

    -------------------------------------------------------------------
    -- B: WITH RECURSIVE portion – “walking” the nested variant tree
    -------------------------------------------------------------------
    SET @cte_part = CONCAT(
        'WITH RECURSIVE VariantAttributeTraversal AS (',
        '  -- Anchor row: start with the chosen variant_attribute ',
        '  SELECT ',
        '    va.id AS variantAttributeId, ',
        '    va.causation_index, ',
        '    va.variant_id AS variantId, ',
        '    vavs.id AS variantAttributeVariantSpanId, ',
        '    cva.id  AS variantAttributeVariantSpanVariantAttributeId, ',
        '    vavs.variant_id AS parentVariantId, ',
        '    1 AS Direction ',
        '  FROM ', v_table_va, ' AS va ',
        '       LEFT JOIN ', v_table_vas, ' AS vavs ',
        '            ON va.id = vavs.variant_attribute_id ',
        '               AND vavs.id = ', p_vavs_id, ' ',
        '       LEFT JOIN ', v_table_vavspan, ' AS cva ',
        '            ON va.id = cva.variant_attribute_id ',
        '  WHERE va.id = ', p_va_id, ' ',

        '  UNION ALL ',

        '  -- Downward recursion (Direction=1): get children with higher causation_index ',
        '  SELECT ',
        '    va_sub.id, ',
        '    va_sub.causation_index, ',
        '    va_sub.variant_id, ',
        '    vavs_sub.id, ',
        '    cva_sub.id, ',
        '    vavs_sub.variant_id, ',
        '    vat.Direction ',
        '  FROM VariantAttributeTraversal AS vat ',
        '       JOIN ', v_table_vas, ' AS vavs_sub ',
        '            ON vat.variantId = vavs_sub.variant_id ',
        '       JOIN ', v_table_va, ' AS va_sub ',
        '            ON vavs_sub.variant_attribute_id = va_sub.id ',
        '            AND vat.causation_index < va_sub.causation_index ',
        '       LEFT JOIN ', v_table_vavspan, ' AS cva_sub ',
        '            ON va_sub.id = cva_sub.variant_attribute_id ',
        '  WHERE vat.Direction = 1 ',

        '  UNION ALL ',

        '  -- Upward recursion: move “up” to parents with lower causation_index and switch Direction ',
        '  SELECT ',
        '    va_parent.id, ',
        '    va_parent.causation_index, ',
        '    va_parent.variant_id, ',
        '    vavs_parent.id, ',
        '    cva_parent.id, ',
        '    vavs_parent.variant_id, ',
        '    CASE ',
        '       WHEN va_parent.id IS NOT NULL THEN 2 ',
        '       ELSE vat.Direction ',
        '    END AS Direction ',
        '  FROM VariantAttributeTraversal AS vat ',
        '       JOIN ', v_table_vas, ' AS vavs_parent ',
        '            ON vat.parentVariantId = vavs_parent.variant_id ',
        '       JOIN ', v_table_va, ' AS va_parent ',
        '            ON vavs_parent.variant_attribute_id = va_parent.id ',
        '            AND vat.causation_index > va_parent.causation_index ',
        '       LEFT JOIN ', v_table_vavspan, ' AS cva_parent ',
        '            ON va_parent.id = cva_parent.variant_attribute_id ',
        ') '
    );

    -------------------------------------------------------------------
    -- C: Base SELECT from the CTE
    -------------------------------------------------------------------
    SET @base_select = CONCAT(
        'SELECT ',
        '  variantAttributeId, ',
        '  variantId, ',
        '  causation_index AS variantAttributeIndex, ',
        '  variantAttributeVariantSpanVariantAttributeId, ',
        '  variantAttributeVariantSpanId ',
        'FROM VariantAttributeTraversal '
    );

    -------------------------------------------------------------------
    -- D: WHERE / ORDER based on p_direction (for “after” or “before” paging)
    -------------------------------------------------------------------
    IF p_direction = 'after' THEN
        SET @where_clause = CONCAT(
            'WHERE Direction = 2 ',
            '  AND (variantId > ? ',
            '       OR (variantId = ? AND variantAttributeIndex > ?)) '
        );
        SET @order_clause = 'ORDER BY variantId ASC, variantAttributeIndex ASC LIMIT ?';
        SET @full_query = CONCAT(@cte_part, @base_select, ' ', @where_clause, ' ', @order_clause);
    ELSE
        SET @inner_query = CONCAT(
            @base_select, ' ',
            'WHERE Direction = 2 ',
            '  AND (variantId < ? ',
            '       OR (variantId = ? AND variantAttributeIndex < ?)) ',
            'ORDER BY variantId DESC, variantAttributeIndex DESC ',
            'LIMIT ?'
        );
        SET @full_query = CONCAT(
            @cte_part,
            'SELECT * FROM (', @inner_query, ') AS tmp ',
            'ORDER BY tmp.variantId ASC, tmp.variantAttributeIndex ASC'
        );
    END IF;

    -------------------------------------------------------------------
    -- E: Prepare & Execute the dynamic SQL
    -------------------------------------------------------------------
    -- The query uses four placeholders:
    --   1) p_variant_id, 2) p_variant_id, 3) p_causation_index, 4) p_limit
    SET @p_variant_id      = p_variant_id;
    SET @p_causation_index = p_causation_index;
    SET @p_limit           = p_limit;

    PREPARE stmt FROM @full_query;
    EXECUTE stmt USING @p_variant_id, @p_variant_id, @p_causation_index, @p_limit;
    DEALLOCATE PREPARE stmt;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE get_delta_weight_options_page (
    IN p_va_id INT,                -- the discrete variant_attribute id
    IN p_cursor_weight DOUBLE,     -- the “cursor” effective weight value (for paging)
    IN p_cursor_id INT,            -- the corresponding span id (tiebreaker)
    IN p_limit INT,
    IN p_direction VARCHAR(6),     -- 'after' or 'before'
    IN p_commitHash VARCHAR(64)    -- for Dolt: optional commit hash
)
BEGIN
    -------------------------------------------------------------------
    -- A: Build dynamic table names based on p_commitHash
    -------------------------------------------------------------------
    DECLARE v_table_va        VARCHAR(200);
    DECLARE v_table_vas       VARCHAR(200);
    DECLARE v_table_span      VARCHAR(200);
    DECLARE v_table_vavspan   VARCHAR(200);
    DECLARE v_table_var_act   VARCHAR(200);
    DECLARE v_table_variation VARCHAR(200);
    DECLARE v_table_var_delta VARCHAR(200);

    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
        SET v_table_va         = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
        SET v_table_vas        = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
        SET v_table_span       = CONCAT('span AS OF ''', p_commitHash, '''');
        SET v_table_vavspan    = CONCAT('vavspan_attr AS OF ''', p_commitHash, '''');
        SET v_table_var_act    = CONCAT('variation_activated_span AS OF ''', p_commitHash, '''');
        SET v_table_variation  = CONCAT('variation AS OF ''', p_commitHash, '''');
        SET v_table_var_delta  = CONCAT('variation_delta_weight AS OF ''', p_commitHash, '''');
    ELSE
        SET v_table_va         = 'variant_attribute';
        SET v_table_vas        = 'variant_attr_span';
        SET v_table_span       = 'span';
        SET v_table_vavspan    = 'vavspan_attr';
        SET v_table_var_act    = 'variation_activated_span';
        SET v_table_variation  = 'variation';
        SET v_table_var_delta  = 'variation_delta_weight';
    END IF;

    -------------------------------------------------------------------
    -- B: Build the UNION query to combine base spans and variation‑activated spans
    --
    -- (i) The “base” query gets spans directly associated with the given
    --     discrete variant_attribute (p_va_id).
    --
    -- (ii) The “variation” query gets spans that have been “activated” via a
    --      variation – that is, variations whose “to‐modify” target (via vavspan_attr)
    --      belongs to the given discrete variant_attribute.
    -------------------------------------------------------------------
    SET @base_query = CONCAT(
        'SELECT s.id AS spanId, s.label, s.weight AS effective_weight, ''base'' AS source ',
        'FROM ', v_table_span, ' s ',
        'JOIN ', v_table_vas, ' vas ON s.id = vas.span_id ',
        'WHERE vas.variant_attribute_id = ? '
    );

    SET @variation_query = CONCAT(
        'SELECT s.id AS spanId, s.label, (s.weight + COALESCE(vdw.delta_weight, 0)) AS effective_weight, ''variation'' AS source ',
        'FROM ', v_table_var_act, ' vas_act ',
        'JOIN ', v_table_variation, ' v ON vas_act.variation_id = v.id AND v.is_inactive = 0 ',
        'JOIN ', v_table_vavspan, ' vav ON v.to_modify_vavspan_attr_id = vav.id AND vav.variant_attribute_id = ? ',
        'JOIN ', v_table_span, ' s ON vas_act.span_id = s.id ',
        'LEFT JOIN ', v_table_var_delta, ' vdw ON v.id = vdw.variation_id AND s.id = vdw.span_id '
    );

    SET @union_query = CONCAT(
        '(', @base_query, ') UNION ALL (', @variation_query, ') '
    );

    -------------------------------------------------------------------
    -- C: Apply pagination conditions.
    --
    -- We order the results by the effective_weight (and spanId as a tiebreaker).
    -- For “after” paging we require:
    --      (effective_weight > cursor_weight) OR
    --      (effective_weight = cursor_weight AND spanId > cursor_id)
    -------------------------------------------------------------------
    IF p_direction = 'after' THEN
        SET @pagination_where = 'WHERE (effective_weight > ? OR (effective_weight = ? AND spanId > ?)) ';
        SET @order_clause = 'ORDER BY effective_weight ASC, spanId ASC ';
    ELSE
        SET @pagination_where = 'WHERE (effective_weight < ? OR (effective_weight = ? AND spanId < ?)) ';
        SET @order_clause = 'ORDER BY effective_weight DESC, spanId DESC ';
    END IF;

    SET @limit_clause = 'LIMIT ?';

    SET @full_query = CONCAT(
        'SELECT * FROM (', @union_query, ') AS t ',
        @pagination_where,
        @order_clause,
        @limit_clause
    );

    -------------------------------------------------------------------
    -- D: Prepare & Execute the dynamic SQL.
    --
    -- Note: The placeholders appear in the following order:
    --   (i) p_va_id for the base query,
    --  (ii) p_va_id for the variation query,
    -- (iii-v) p_cursor_weight, p_cursor_weight, p_cursor_id for paging,
    --  (vi) p_limit.
    -------------------------------------------------------------------
    SET @p_va_id = p_va_id;
    SET @p_cursor_weight = p_cursor_weight;
    SET @p_cursor_id = p_cursor_id;
    SET @p_limit = p_limit;

    PREPARE stmt FROM @full_query;
    EXECUTE stmt USING @p_va_id, @p_va_id, @p_cursor_weight, @p_cursor_weight, @p_cursor_id, @p_limit;
    DEALLOCATE PREPARE stmt;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE roll_discrete_varattr (
    IN p_variantAttributeId INT UNSIGNED,
    IN p_variantAttrVariantSpanId INT UNSIGNED,  -- now required
    IN p_excludeSpanId INT UNSIGNED,
    IN p_commitHash VARCHAR(64)
)
BEGIN
    -------------------------------------------------------------------------
    -- 1) Build dynamic "AS OF" table names (if a commit hash is provided)
    -------------------------------------------------------------------------
    DECLARE v_table_va       VARCHAR(200);
    DECLARE v_table_vas      VARCHAR(200);
    DECLARE v_table_span     VARCHAR(200);
    DECLARE v_table_vavspan  VARCHAR(200);
    DECLARE v_table_variation VARCHAR(200);
    DECLARE v_table_var_inactive  VARCHAR(200);
    DECLARE v_table_var_activated VARCHAR(200);
    DECLARE v_table_var_delta     VARCHAR(200);

    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
        SET v_table_va           = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
        SET v_table_vas          = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
        SET v_table_span         = CONCAT('span AS OF ''', p_commitHash, '''');
        SET v_table_vavspan      = CONCAT('vavspan_attr AS OF ''', p_commitHash, '''');
        SET v_table_variation    = CONCAT('variation AS OF ''', p_commitHash, '''');
        SET v_table_var_inactive = CONCAT('variation_inactive_span AS OF ''', p_commitHash, '''');
        SET v_table_var_activated= CONCAT('variation_activated_span AS OF ''', p_commitHash, '''');
        SET v_table_var_delta    = CONCAT('variation_delta_weight AS OF ''', p_commitHash, '''');
    ELSE
        SET v_table_va           = 'variant_attribute';
        SET v_table_vas          = 'variant_attr_span';
        SET v_table_span         = 'span';
        SET v_table_vavspan      = 'vavspan_attr';
        SET v_table_variation    = 'variation';
        SET v_table_var_inactive = 'variation_inactive_span';
        SET v_table_var_activated= 'variation_activated_span';
        SET v_table_var_delta    = 'variation_delta_weight';
    END IF;

    -------------------------------------------------------------------------
    -- 2) Build dynamic SQL to create a temporary table _OrderedSpans.
    --    The candidate spans are restricted to those linked (via variant_attr_span)
    --    using the passed p_variantAttrVariantSpanId.
    -------------------------------------------------------------------------
    SET @sql = CONCAT(
        'CREATE TEMPORARY TABLE IF NOT EXISTS _OrderedSpans AS ',
        'WITH ',
        'BaseSpans AS (',
        '   SELECT s.id AS span_id, ',
        '          va.id AS variant_attribute_id, ',
        '          vas.id AS variant_attr_span_id, ',
        '          s.weight AS base_weight ',
        '   FROM ', v_table_va, ' va ',
        '   JOIN ', v_table_span, ' s ON s.attribute_id = va.attribute_id ',
        '   LEFT JOIN ', v_table_vas, ' vas ON vas.variant_attribute_id = va.id ',
        '         AND vas.span_id = s.id ',
        '   WHERE va.id = ', p_variantAttributeId, ' ',
        '     AND s.type = ''discrete'' ',
        '     AND (', p_excludeSpanId, ' = 0 OR s.id <> ', p_excludeSpanId, ') ',
        '     AND s.id IN ( ',
        '         SELECT s2.id ',
        '         FROM ', v_table_span, ' s2 ',
        '         JOIN ', v_table_vas, ' vas2 ON vas2.span_id = s2.id ',
        '            AND vas2.variant_attribute_id = va.id ',
        '         WHERE vas2.id = ', p_variantAttrVariantSpanId,
        '     )',
        '), ',
        'ActiveVariations AS (',
        '   SELECT v.id AS variation_id, vav.variant_attribute_id ',
        '   FROM ', v_table_variation, ' v ',
        '   JOIN ', v_table_vavspan, ' vav ON vav.id = v.to_modify_vavspan_attr_id ',
        '         AND vav.variant_attribute_id = ', p_variantAttributeId, ' ',
        '   WHERE v.is_inactive = 0 ',
        '), ',
        'InactiveSpans AS (',
        '   SELECT DISTINCT vis.span_id ',
        '   FROM ', v_table_var_inactive, ' vis ',
        '   JOIN ActiveVariations av ON av.variation_id = vis.variation_id ',
        '), ',
        'ActivatedSpans AS (',
        '   SELECT DISTINCT vas.span_id, av.variant_attribute_id, NULL AS variant_attr_span_id, 0.0 AS base_weight ',
        '   FROM ', v_table_var_activated, ' vas ',
        '   JOIN ActiveVariations av ON av.variation_id = vas.variation_id ',
        '), ',
        'DeltaWeights AS (',
        '   SELECT vdw.span_id, SUM(vdw.delta_weight) AS total_delta ',
        '   FROM ', v_table_var_delta, ' vdw ',
        '   JOIN ActiveVariations av ON av.variation_id = vdw.variation_id ',
        '   GROUP BY vdw.span_id ',
        '), ',
        'AllRelevantSpans AS (',
        '   SELECT b.span_id, b.variant_attribute_id, b.variant_attr_span_id, b.base_weight ',
        '   FROM BaseSpans b ',
        '   WHERE b.span_id NOT IN (SELECT span_id FROM InactiveSpans) ',
        '   UNION ',
        '   SELECT a.span_id, a.variant_attribute_id, a.variant_attr_span_id, a.base_weight ',
        '   FROM ActivatedSpans a ',
        '   WHERE a.span_id NOT IN (SELECT span_id FROM InactiveSpans) ',
        '), ',
        'FinalSpans AS (',
        '   SELECT ars.span_id, ars.variant_attribute_id, ars.variant_attr_span_id, ',
        '          COALESCE(ars.base_weight, 0) + COALESCE(dw.total_delta, 0) AS effective_weight ',
        '   FROM AllRelevantSpans ars ',
        '   LEFT JOIN DeltaWeights dw ON dw.span_id = ars.span_id ',
        '), ',
        'OrderedSpans AS (',
        '   SELECT fs.span_id, fs.variant_attribute_id, fs.variant_attr_span_id, ',
        '          fs.effective_weight AS contextualWeight, ',
        '          SUM(fs.effective_weight) OVER (ORDER BY fs.span_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS runningTotal, ',
        '          LAG(SUM(fs.effective_weight) OVER (ORDER BY fs.span_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 1, 0) OVER (ORDER BY fs.span_id) AS prevRunningTotal ',
        '   FROM FinalSpans fs ',
        '   WHERE fs.effective_weight > 0 ',
        '   ORDER BY fs.span_id ',
        ') ',
        'SELECT * FROM OrderedSpans;'
    );

    -------------------------------------------------------------------------
    -- 3) Create _OrderedSpans, pick a random value, and select the span covering it.
    -------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS _OrderedSpans;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    DECLARE v_totalWeight DOUBLE DEFAULT 0;
    DECLARE v_randomPick  BIGINT UNSIGNED DEFAULT 0;
    SELECT COALESCE(MAX(runningTotal), 0) INTO v_totalWeight FROM _OrderedSpans;
    IF v_totalWeight <= 0 THEN
        SELECT NULL AS span_id,
               NULL AS variant_attribute_id,
               NULL AS variant_attr_span_id,
               0 AS contextualWeight,
               0 AS runningTotal,
               0 AS prevRunningTotal;
        RETURN;
    END IF;
    SET v_randomPick = FLOOR(RAND() * v_totalWeight);
    SELECT span_id INTO @span_id
      FROM _OrderedSpans
     WHERE v_randomPick >= prevRunningTotal
       AND v_randomPick < runningTotal
     LIMIT 1;
    DROP TEMPORARY TABLE IF EXISTS _OrderedSpans;
END $$
DELIMITER $$


DELIMITER $$
CREATE PROCEDURE roll_continuous_varattr (
    IN p_variantAttributeId INT UNSIGNED,
    IN p_variantAttrVariantSpanId INT UNSIGNED,  -- now required
    IN p_excludeSpanId INT UNSIGNED,
    IN p_commitHash VARCHAR(64)
)
BEGIN
    pick_continuous_span_proc: BEGIN
        ############################################################################
        # A) Set up commit-hash–based table references
        ############################################################################
        DECLARE v_table_va           VARCHAR(200);
        DECLARE v_table_span         VARCHAR(200);
        DECLARE v_table_vas          VARCHAR(200);
        DECLARE v_table_variation    VARCHAR(200);
        DECLARE v_table_vavspan      VARCHAR(200);
        DECLARE v_table_var_cont     VARCHAR(200);

        IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
            SET v_table_va        = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
            SET v_table_span      = CONCAT('span AS OF ''', p_commitHash, '''');
            SET v_table_vas       = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
            SET v_table_variation = CONCAT('variation AS OF ''', p_commitHash, '''');
            SET v_table_vavspan   = CONCAT('vavspan_attr AS OF ''', p_commitHash, '''');
            SET v_table_var_cont  = CONCAT('variation_continuous_attr AS OF ''', p_commitHash, '''');
        ELSE
            SET v_table_va        = 'variant_attribute';
            SET v_table_span      = 'span';
            SET v_table_vas       = 'variant_attr_span';
            SET v_table_variation = 'variation';
            SET v_table_vavspan   = 'vavspan_attr';
            SET v_table_var_cont  = 'variation_continuous_attr';
        END IF;

        ############################################################################
        # B) Retrieve the continuous attribute details for p_variantAttributeId.
        ############################################################################
        DECLARE v_attributeId INT UNSIGNED;
        DECLARE v_decimals INT DEFAULT 0;
        DECLARE v_min DOUBLE;
        DECLARE v_max DOUBLE;
        DECLARE v_normal DOUBLE;
        DECLARE v_percentNormal DOUBLE;
        DECLARE v_percentPinned DOUBLE;
        DECLARE v_percentSkewed DOUBLE;

        SET @sql_attr = CONCAT(
          'SELECT va.attribute_id, a.decimals, ',
          '       a.min_value, a.max_value, a.normal_value, ',
          '       a.percent_normal, a.percent_pinned, a.percent_skewed ',
          '  FROM ', v_table_va, ' va ',
          '  JOIN attribute a ON a.id = va.attribute_id ',
          ' WHERE va.id = ? ',
          ' LIMIT 1'
        );
        PREPARE stmt_attr FROM @sql_attr;
        SET @p_vaId := p_variantAttributeId;
        EXECUTE stmt_attr USING @p_vaId;
        DEALLOCATE PREPARE stmt_attr;

        SELECT @attribute_id, @decimals, @min_value, @max_value, @normal_value,
               @percent_normal, @percent_pinned, @percent_skewed
          INTO v_attributeId, v_decimals, v_min, v_max, v_normal,
               v_percentNormal, v_percentPinned, v_percentSkewed;

        IF v_attributeId IS NULL THEN
           SELECT 'No matching attribute found' AS error_message;
           LEAVE pick_continuous_span_proc;
        END IF;

        ############################################################################
        # C) Sum up all variation deltas for this attribute, restricted by the active
        #    variant_attr_span (using p_variantAttrVariantSpanId).
        ############################################################################
        DECLARE v_totalDeltaNormal DOUBLE DEFAULT 0;
        DECLARE v_totalDeltaPnormal DOUBLE DEFAULT 0;
        DECLARE v_totalDeltaPskew DOUBLE DEFAULT 0;

        SET @sql_summed = CONCAT(
          'SELECT ',
          '   COALESCE(SUM(vca.delta_normal),0) AS total_delta_normal, ',
          '   COALESCE(SUM(vca.delta_percent_normal),0) AS total_delta_pnormal, ',
          '   COALESCE(SUM(vca.delta_percent_skewed),0) AS total_delta_pskew ',
          '  FROM ', v_table_var_cont, ' vca ',
          '  JOIN ( ',
          '      SELECT v.id AS variation_id ',
          '        FROM ', v_table_variation, ' v ',
          '        JOIN ', v_table_vavspan, ' vav ',
          '          ON vav.id = v.to_modify_vavspan_attr_id ',
          '         AND vav.variant_attribute_id = ? ',
          '         AND vav.id = ', p_variantAttrVariantSpanId, ' ',
          '       WHERE v.is_inactive = 0 ',
          '  ) av ON av.variation_id = vca.variation_id'
        );
        PREPARE stmt_summed FROM @sql_summed;
        SET @p_vaId2 := p_variantAttributeId;
        EXECUTE stmt_summed USING @p_vaId2;
        DEALLOCATE PREPARE stmt_summed;

        SELECT @total_delta_normal, @total_delta_pnormal, @total_delta_pskew
          INTO v_totalDeltaNormal, v_totalDeltaPnormal, v_totalDeltaPskew;

        ############################################################################
        # D) Compute the effective min, max, and normal values (after applying deltas).
        ############################################################################
        DECLARE v_effMin DOUBLE;
        DECLARE v_effMax DOUBLE;
        DECLARE v_effNormal DOUBLE;

        SET v_effMin = CASE
             WHEN (v_totalDeltaPnormal <> 0 OR v_totalDeltaPskew <> 0)
             THEN (v_min + v_totalDeltaNormal) * (1 + v_totalDeltaPnormal + v_totalDeltaPskew)
             ELSE (v_min + v_totalDeltaNormal)
           END;
        SET v_effMax = CASE
             WHEN (v_totalDeltaPnormal <> 0 OR v_totalDeltaPskew <> 0)
             THEN (v_max + v_totalDeltaNormal) * (1 + v_totalDeltaPnormal + v_totalDeltaPskew)
             ELSE (v_max + v_totalDeltaNormal)
           END;
        SET v_effNormal = CASE
             WHEN (v_totalDeltaPnormal <> 0 OR v_totalDeltaPskew <> 0)
             THEN (v_normal + v_totalDeltaNormal) * (1 + v_totalDeltaPnormal + v_totalDeltaPskew)
             ELSE (v_normal + v_totalDeltaNormal)
           END;

        IF v_effMax < v_effMin THEN
            SET @tmp = v_effMin;
            SET v_effMin = v_effMax;
            SET v_effMax = @tmp;
        END IF;

        ############################################################################
        # E) Generate a skewed random number within the effective range.
        ############################################################################
        DECLARE v_totalDiscreteValues DOUBLE;
        DECLARE v_randomUniform DOUBLE;
        DECLARE v_midpoint DOUBLE;
        DECLARE v_skewOffset DOUBLE;
        DECLARE v_normalOffset DOUBLE;
        DECLARE v_degreeEstimate DOUBLE;
        DECLARE v_discreteDegreeEstimate DOUBLE;
        DECLARE v_cubicDegreeEstimate DOUBLE;
        DECLARE v_skewed DOUBLE;
        DECLARE v_distributed DOUBLE;
        DECLARE v_multiplier DOUBLE;
        DECLARE v_offset DOUBLE;
        DECLARE v_result DOUBLE;
        DECLARE v_clampedResult DOUBLE;

        SET v_totalDiscreteValues = (v_effMax - v_effMin) * POW(10, v_decimals) + 1;
        IF v_totalDiscreteValues < 1 THEN
            SET v_totalDiscreteValues = 1;
        END IF;
        SET v_randomUniform = RAND() * v_totalDiscreteValues;
        SET v_midpoint = v_totalDiscreteValues / 2;
        SET v_skewOffset = (-v_midpoint * IFNULL(v_percentSkewed, 0)) / 100;
        SET v_normalOffset = v_effNormal - ((v_effMax - v_effMin)/2) - v_effMin;
        IF v_percentNormal IS NULL OR v_percentNormal <= 0 THEN
           SET v_percentNormal = 0;
        END IF;
        SET v_degreeEstimate = -2.3 / LN((v_percentNormal/100) + 0.000052) - 0.5;
        SET @mult = FLOOR(v_degreeEstimate / 0.04);
        SET v_discreteDegreeEstimate = v_degreeEstimate - (@mult * 0.04);
        SET v_cubicDegreeEstimate = 1 + 2 * v_discreteDegreeEstimate;
        SET v_skewed = v_randomUniform - v_midpoint - v_skewOffset;
        SET v_distributed = SIGN(v_skewed) * POW(ABS(v_skewed), v_cubicDegreeEstimate);
        IF (v_totalDiscreteValues - 2*v_skewOffset*SIGN(v_skewed)) = 0 THEN
            SET v_multiplier = 0;
        ELSE
            SET v_multiplier = ((v_effMax - v_effMin) * POW(4, v_discreteDegreeEstimate))
                / POW((v_totalDiscreteValues - 2*v_skewOffset*SIGN(v_skewed)), v_cubicDegreeEstimate);
        END IF;
        SET @avg = (v_effMin + v_effMax)/2;
        SET v_offset = ((-2 * v_normalOffset * v_multiplier * ABS(v_distributed)) / (v_effMax - v_effMin))
                       + v_normalOffset + @avg;
        SET v_result = v_multiplier * v_distributed + v_offset;
        SET v_result = ROUND(v_result, v_decimals);
        IF v_result < v_effMin THEN
           SET v_clampedResult = v_effMin;
        ELSEIF v_result > v_effMax THEN
           SET v_clampedResult = v_effMax;
        ELSE
           SET v_clampedResult = v_result;
        END IF;

        ############################################################################
        # F) Select the continuous span whose effective boundaries enclose the value,
        #    joining with variant_attr_span so that only the span associated with the
        #    passed p_variantAttrVariantSpanId is considered.
        ############################################################################
        DECLARE v_chosenSpanId INT UNSIGNED DEFAULT NULL;
        DECLARE v_chosenEffMin DOUBLE;
        DECLARE v_chosenEffMax DOUBLE;

        SET @sql_span = CONCAT(
           'SELECT s.id, ',
           '       CASE WHEN (@pPnormal <> 0 OR @pPskew <> 0) ',
           '            THEN (s.min_value + @pDeltaNormal) * (1 + @pPnormal + @pPskew) ',
           '            ELSE (s.min_value + @pDeltaNormal) ',
           '       END AS eff_min, ',
           '       CASE WHEN (@pPnormal <> 0 OR @pPskew <> 0) ',
           '            THEN (s.max_value + @pDeltaNormal) * (1 + @pPnormal + @pPskew) ',
           '            ELSE (s.max_value + @pDeltaNormal) ',
           '       END AS eff_max ',
           '  FROM ', v_table_span, ' s ',
           '  JOIN ', v_table_vas, ' vas ON vas.span_id = s.id ',
           ' WHERE s.attribute_id = ? ',
           '   AND s.type = ''continuous'' ',
           '   AND vas.id = ', p_variantAttrVariantSpanId, ' ',
           'HAVING eff_min <= ', CAST(v_clampedResult AS CHAR),
           '  AND eff_max > ', CAST(v_clampedResult AS CHAR),
           ' LIMIT 1'
        );
        PREPARE stmt_span FROM @sql_span;
        SET @pDeltaNormal := v_totalDeltaNormal;
        SET @pPnormal := v_totalDeltaPnormal;
        SET @pPskew := v_totalDeltaPskew;
        SET @p_attrId := v_attributeId;
        EXECUTE stmt_span USING @p_attrId;
        DEALLOCATE PREPARE stmt_span;

        SELECT @span_id, @span_eff_min, @span_eff_max
          INTO v_chosenSpanId, v_chosenEffMin, v_chosenEffMax;

        IF v_chosenSpanId IS NOT NULL THEN
            SET @span_id = v_chosenSpanId;
            SET @chosen_value = v_clampedResult;
        ELSE
            SET @span_id = NULL;
            SET @chosen_value = v_clampedResult;
        END IF;
    END;
END $$
DELIMITER $$


DELIMITER $$
CREATE PROCEDURE generate_entity_state(
    IN p_entity_id INT UNSIGNED,
    IN p_time DOUBLE,
    IN p_commitHash VARCHAR(64)  -- optional Dolt commit-hash
)
BEGIN
    generate_entity_state_proc: BEGIN
        ----------------------------------------------------------------------
        -- 0) Retrieve the top-level variant associated with the entity.
        ----------------------------------------------------------------------
        DECLARE v_root_variant_id INT UNSIGNED;
        DECLARE v_entity_state_id INT UNSIGNED;

        IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
            SET @table_entity = CONCAT('entity AS OF ''', p_commitHash, '''');
            SET @sql = CONCAT('SELECT variant_id FROM ', @table_entity, ' WHERE id = ', p_entity_id, ' LIMIT 1');
            PREPARE stmt FROM @sql;
            EXECUTE stmt INTO v_root_variant_id;
            DEALLOCATE PREPARE stmt;
        ELSE
            SELECT variant_id INTO v_root_variant_id
              FROM entity
             WHERE id = p_entity_id
             LIMIT 1;
        END IF;

        IF v_root_variant_id IS NULL THEN
           SELECT CONCAT('No entity found with id=', p_entity_id) AS error_message;
           LEAVE generate_entity_state_proc;
        END IF;

        ----------------------------------------------------------------------
        -- 1) Insert a new entity_state row.
        ----------------------------------------------------------------------
        INSERT INTO entity_state (entity_id, `time`)
        VALUES (p_entity_id, p_time);
        SET v_entity_state_id = LAST_INSERT_ID();

        ----------------------------------------------------------------------
        -- 2) Initialize a temporary queue with the top-level variant.
        ----------------------------------------------------------------------
        DROP TEMPORARY TABLE IF EXISTS _VariantQueue;
        CREATE TEMPORARY TABLE _VariantQueue (
           variant_id INT UNSIGNED NOT NULL
        ) ENGINE=MEMORY;
        INSERT INTO _VariantQueue(variant_id) VALUES (v_root_variant_id);

        ----------------------------------------------------------------------
        -- 3) Process each variant in the queue.
        ----------------------------------------------------------------------
        WHILE (SELECT COUNT(*) FROM _VariantQueue) > 0 DO
            -------------------------------------------------------------------
            -- 3A) Pop one variant from the queue.
            -------------------------------------------------------------------
            DECLARE v_current_variant INT UNSIGNED;
            SELECT variant_id INTO v_current_variant FROM _VariantQueue LIMIT 1;
            DELETE FROM _VariantQueue WHERE variant_id = v_current_variant LIMIT 1;

            -------------------------------------------------------------------
            -- 3B) Retrieve all variant_attribute rows for this variant.
            -------------------------------------------------------------------
            DROP TEMPORARY TABLE IF EXISTS _VariantAttributes;
            CREATE TEMPORARY TABLE _VariantAttributes (
                va_id INT UNSIGNED,
                attr_type ENUM('discrete','continuous')
            ) ENGINE=MEMORY;

            IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
                SET @table_variant_attribute = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
                SET @table_attribute = CONCAT('attribute AS OF ''', p_commitHash, '''');
                SET @sql = CONCAT(
                   'INSERT INTO _VariantAttributes (va_id, attr_type) ',
                   'SELECT va.id, a.type FROM ', @table_variant_attribute, ' va ',
                   'JOIN ', @table_attribute, ' a ON a.id = va.attribute_id ',
                   'WHERE va.variant_id = ', v_current_variant
                );
                PREPARE stmt FROM @sql;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;
            ELSE
                INSERT INTO _VariantAttributes (va_id, attr_type)
                SELECT va.id, a.type FROM variant_attribute va
                JOIN attribute a ON a.id = va.attribute_id
                WHERE va.variant_id = v_current_variant;
            END IF;

            -------------------------------------------------------------------
            -- 3C) For each variant_attribute, look up its active variant_attr_span
            --      record and then call the appropriate pick procedure.
            -------------------------------------------------------------------
            DECLARE done INT DEFAULT FALSE;
            DECLARE cur_va_id INT UNSIGNED;
            DECLARE cur_attr_type ENUM('discrete','continuous');
            DECLARE v_variantAttrVariantSpanId INT UNSIGNED;
            DECLARE va_cursor CURSOR FOR
                SELECT va_id, attr_type FROM _VariantAttributes;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

            OPEN va_cursor;
            read_loop: LOOP
                FETCH va_cursor INTO cur_va_id, cur_attr_type;
                IF done THEN
                    LEAVE read_loop;
                END IF;

                -- Look up the active variant_attr_span record for this attribute and variant.
                SELECT id INTO v_variantAttrVariantSpanId
                  FROM variant_attr_span
                 WHERE variant_attribute_id = cur_va_id
                   AND variant_id = v_current_variant
                 LIMIT 1;

                IF cur_attr_type = 'discrete' THEN
                    CALL roll_discrete_varattr(
                        p_variantAttributeId       := cur_va_id,
                        p_variantAttrVariantSpanId := v_variantAttrVariantSpanId,
                        p_excludeSpanId            := 0,
                        p_commitHash               := p_commitHash
                    );
                    SELECT @span_id INTO @d_span_id;
                    INSERT INTO entity_varattr_value (
                        entity_state_id,
                        numeric_value,
                        span_id,
                        variant_attribute_id
                    ) VALUES (
                        v_entity_state_id,
                        NULL,
                        @d_span_id,
                        cur_va_id
                    );

                    -- Check if this attribute’s chosen span activates a sub–variant.
                    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
                        SET @table_var_attr_span = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
                        SET @sql = CONCAT(
                            'SELECT variant_id FROM ', @table_var_attr_span,
                            ' WHERE variant_attribute_id = ', cur_va_id,
                            ' AND id = ', v_variantAttrVariantSpanId,
                            ' LIMIT 1'
                        );
                        PREPARE stmt FROM @sql;
                        EXECUTE stmt INTO @sub_variant_id;
                        DEALLOCATE PREPARE stmt;
                    ELSE
                        SELECT variant_id INTO @sub_variant_id
                          FROM variant_attr_span
                         WHERE variant_attribute_id = cur_va_id
                           AND id = v_variantAttrVariantSpanId
                         LIMIT 1;
                    END IF;
                    IF @sub_variant_id IS NOT NULL AND @sub_variant_id <> v_current_variant THEN
                        INSERT INTO _VariantQueue(variant_id) VALUES (@sub_variant_id);
                    END IF;

                ELSEIF cur_attr_type = 'continuous' THEN
                    CALL roll_continuous_varattr(
                        p_variantAttributeId       := cur_va_id,
                        p_variantAttrVariantSpanId := v_variantAttrVariantSpanId,
                        p_excludeSpanId            := 0,
                        p_commitHash               := p_commitHash
                    );
                    SELECT @span_id, @chosen_value INTO @c_span_id, @c_numeric;
                    INSERT INTO entity_varattr_value (
                        entity_state_id,
                        numeric_value,
                        span_id,
                        variant_attribute_id
                    ) VALUES (
                        v_entity_state_id,
                        @c_numeric,
                        @c_span_id,
                        cur_va_id
                    );

                    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
                        SET @table_var_attr_span = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
                        SET @sql = CONCAT(
                            'SELECT variant_id FROM ', @table_var_attr_span,
                            ' WHERE variant_attribute_id = ', cur_va_id,
                            ' AND id = ', v_variantAttrVariantSpanId,
                            ' LIMIT 1'
                        );
                        PREPARE stmt FROM @sql;
                        EXECUTE stmt INTO @sub_variant_id;
                        DEALLOCATE PREPARE stmt;
                    ELSE
                        SELECT variant_id INTO @sub_variant_id
                          FROM variant_attr_span
                         WHERE variant_attribute_id = cur_va_id
                           AND id = v_variantAttrVariantSpanId
                         LIMIT 1;
                    END IF;
                    IF @sub_variant_id IS NOT NULL AND @sub_variant_id <> v_current_variant THEN
                        INSERT INTO _VariantQueue(variant_id) VALUES (@sub_variant_id);
                    END IF;
                END IF;
            END LOOP;
            CLOSE va_cursor;
            DROP TEMPORARY TABLE IF EXISTS _VariantAttributes;
        END WHILE;

        ----------------------------------------------------------------------
        -- 4) Return the new entity_state id.
        ----------------------------------------------------------------------
        SELECT v_entity_state_id AS new_entity_state_id;
    END;
END $$
DELIMITER $$


DELIMITER $$

CREATE PROCEDURE reroll_entity_varattr_value(
    IN p_entityVarAttrValueId INT UNSIGNED,
    IN p_excludeCurrent BOOLEAN,    -- if TRUE, exclude the span currently stored in the entity_varattr_value record
    IN p_commitHash VARCHAR(64)
)
BEGIN
    ----------------------------------------------------------------------------
    -- Declare local variables for lookups
    ----------------------------------------------------------------------------
    DECLARE v_variantAttributeId INT UNSIGNED;
    DECLARE v_currentSpanId      INT UNSIGNED DEFAULT 0;
    DECLARE v_attributeType      ENUM('discrete','continuous');
    DECLARE v_variantAttrVariantSpanId INT UNSIGNED;
    DECLARE v_excludeSpanId      INT UNSIGNED;
    
    ----------------------------------------------------------------------------
    -- Build dynamic table names so that lookups use the commit_hash AS OF clause.
    ----------------------------------------------------------------------------
    DECLARE v_entity_table   VARCHAR(200);
    DECLARE v_va_table       VARCHAR(200);
    DECLARE v_attr_table     VARCHAR(200);
    DECLARE v_vavspan_table  VARCHAR(200);
    
    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
        SET v_entity_table  = CONCAT('entity_varattr_value AS OF ''', p_commitHash, '''');
        SET v_va_table      = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
        SET v_attr_table    = CONCAT('attribute AS OF ''', p_commitHash, '''');
        SET v_vavspan_table = CONCAT('vavspan_attr AS OF ''', p_commitHash, '''');
    ELSE
        SET v_entity_table  = 'entity_varattr_value';
        SET v_va_table      = 'variant_attribute';
        SET v_attr_table    = 'attribute';
        SET v_vavspan_table = 'vavspan_attr';
    END IF;
    
    ----------------------------------------------------------------------------
    -- 1) Retrieve the variant_attribute_id (and current span, if any) for the given
    --    entity_varattr_value record using the dynamic table name.
    ----------------------------------------------------------------------------
    SET @sql = CONCAT(
         'SELECT variant_attribute_id, IFNULL(span_id, 0) ',
         'FROM ', v_entity_table, ' ',
         'WHERE id = ?'
    );
    PREPARE stmt FROM @sql;
    SET @p_evaid = p_entityVarAttrValueId;
    EXECUTE stmt USING @p_evaid INTO v_variantAttributeId, v_currentSpanId;
    DEALLOCATE PREPARE stmt;
    
    ----------------------------------------------------------------------------
    -- 2) Lookup the attribute type by joining variant_attribute and attribute,
    --    using the dynamic table names.
    ----------------------------------------------------------------------------
    SET @sql = CONCAT(
         'SELECT a.type ',
         'FROM ', v_va_table, ' va ',
         'JOIN ', v_attr_table, ' a ON a.id = va.attribute_id ',
         'WHERE va.id = ? LIMIT 1'
    );
    PREPARE stmt FROM @sql;
    SET @p_va = v_variantAttributeId;
    EXECUTE stmt USING @p_va INTO v_attributeType;
    DEALLOCATE PREPARE stmt;
    
    ----------------------------------------------------------------------------
    -- 3) Retrieve the candidate variant_attr_span id from the linking table.
    ----------------------------------------------------------------------------
    SET @sql = CONCAT(
         'SELECT variant_attr_span_id ',
         'FROM ', v_vavspan_table, ' ',
         'WHERE variant_attribute_id = ? LIMIT 1'
    );
    PREPARE stmt FROM @sql;
    SET @p_va2 = v_variantAttributeId;
    EXECUTE stmt USING @p_va2 INTO v_variantAttrVariantSpanId;
    DEALLOCATE PREPARE stmt;
    
    ----------------------------------------------------------------------------
    -- 4) If the caller wants to exclude the current span, use that; otherwise 0.
    ----------------------------------------------------------------------------
    SET v_excludeSpanId = IF(p_excludeCurrent, v_currentSpanId, 0);
    
    ----------------------------------------------------------------------------
    -- 5) Depending on the attribute type, call the appropriate pick procedure.
    --    Both procedures are passed the commit hash so that they use AS OF lookups.
    ----------------------------------------------------------------------------
    IF v_attributeType = 'discrete' THEN
        CALL roll_discrete_varattr(
             v_variantAttributeId,
             v_variantAttrVariantSpanId,
             v_excludeSpanId,
             p_commitHash
        );
        -- The roll_discrete_varattr procedure sets @span_id.
        UPDATE entity_varattr_value
          SET span_id = @span_id,
              numeric_value = NULL
         WHERE id = p_entityVarAttrValueId;
    ELSEIF v_attributeType = 'continuous' THEN
        CALL roll_continuous_varattr(
             v_variantAttributeId,
             v_variantAttrVariantSpanId,
             v_excludeSpanId,
             p_commitHash
        );
        -- The roll_continuous_varattr procedure sets both @span_id and @chosen_value.
        UPDATE entity_varattr_value
          SET span_id = @span_id,
              numeric_value = @chosen_value
         WHERE id = p_entityVarAttrValueId;
    ELSE
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Unknown attribute type';
    END IF;
    
    ----------------------------------------------------------------------------
    -- 6) Return the updated entity_varattr_value record.
    ----------------------------------------------------------------------------
    SELECT *
      FROM entity_varattr_value
     WHERE id = p_entityVarAttrValueId;
    
END $$
DELIMITER ;



DELIMITER $$
CREATE PROCEDURE set_discrete_span_percentage (
    IN in_span_id INT UNSIGNED,
    IN in_new_fraction DOUBLE
)
BEGIN
    /* -------------------------------------------------------------------------
       in_span_id      = the ID of the discrete span we want to change
       in_new_fraction = the desired new fraction of the total (e.g. 0.25 = 25%)
       
       Steps:
         1) Identify the attribute to which in_span_id belongs. 
         2) Gather total current weight for all discrete spans of that attribute.
         3) Gather total pinned weight for all discrete spans of that attribute.
         4) Check if the requested new fraction is feasible (must not exceed
            (1 - pinned_fraction)).
         5) Compute the scaling factor for the other unpinned spans.
         6) Update the target span to the new fraction, scaled to the original total.
         7) Rescale the other unpinned spans proportionally.
         8) Ensure that pinned spans remain pinned in fraction (so we do NOT update
            pinned spans' absolute weights).
         9) Because weight is INT, apply rounding and finally correct any rounding
            drift so that the total remains exactly the same as before.
         10) If the sum of pinned fractions + the requested new fraction > 1,
             throw an error.
       ------------------------------------------------------------------------- */

    DECLARE v_attr_id INT UNSIGNED;
    DECLARE v_total_weight INT;         -- The sum of all discrete spans' weights (for this attribute)
    DECLARE v_pinned_weight INT;        -- The sum of pinned spans' weights (for this attribute)
    DECLARE v_pinned_fraction DOUBLE;   -- pinned_weight / total_weight
    DECLARE v_old_weight INT;           -- Old weight of the target span
    DECLARE v_old_fraction DOUBLE;      -- old_weight / total_weight
    DECLARE v_factor DOUBLE;            -- scaling factor for the other unpinned spans
    DECLARE v_new_weight DOUBLE;        -- floating value for the target's new weight (before rounding)
    DECLARE v_new_sum INT;              -- sum of all spans after updates
    DECLARE v_diff INT;                 -- final rounding difference

    -- 1) Identify this span's attribute and current weight
    SELECT attribute_id, weight
      INTO v_attr_id, v_old_weight
      FROM span
     WHERE id = in_span_id
       AND type = 'discrete';

    -- 2) Sum of all discrete weights for that attribute
    SELECT COALESCE(SUM(weight), 0)
      INTO v_total_weight
      FROM span
     WHERE attribute_id = v_attr_id
       AND type = 'discrete';

    -- 3) Sum of pinned weights (discrete only)
    SELECT COALESCE(SUM(weight), 0)
      INTO v_pinned_weight
      FROM span
     WHERE attribute_id = v_attr_id
       AND type = 'discrete'
       AND is_percentage_pinned = 1;

    IF v_total_weight = 0 THEN
        -- No discrete spans at all or something unusual
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot proceed: total weight is 0 or no discrete spans exist.';
    END IF;

    SET v_old_fraction = v_old_weight / v_total_weight;
    SET v_pinned_fraction = v_pinned_weight / v_total_weight;

    -- 4) Check feasibility
    IF (in_new_fraction + v_pinned_fraction) > 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: new fraction would exceed available unpinned portion.';
    END IF;

    -- Special edge case if old_fraction == (1 - v_pinned_fraction) => it was the only unpinned span
    -- if so, we can only set it to the entire unpinned portion:
    IF ABS( (1 - v_pinned_fraction) - v_old_fraction ) < 1e-12 THEN
        -- The current span is effectively the only unpinned span
        IF ABS(in_new_fraction - (1 - v_pinned_fraction)) > 1e-12 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error: cannot set new fraction to anything but 1-pinned_fraction when only one unpinned span exists.';
        END IF;
        -- else it is the same fraction anyway, so no real change is needed
    ELSE
        -- 5) Compute scale factor for other unpinned spans
        SET v_factor = ((1 - v_pinned_fraction) - in_new_fraction)
                     / ((1 - v_pinned_fraction) - v_old_fraction);
        
        -- 6) Update the OTHER unpinned spans (not pinned, not target)
        UPDATE span
           SET weight = ROUND(weight * v_factor)
         WHERE attribute_id = v_attr_id
           AND type = 'discrete'
           AND is_percentage_pinned = 0
           AND id <> in_span_id;

        -- 7) Update the target span (the new fraction times the original total)
        SET v_new_weight = (in_new_fraction * v_total_weight);
        UPDATE span
           SET weight = ROUND(v_new_weight)
         WHERE id = in_span_id;
    END IF;

    -- 8) Pinned spans remain pinned in fraction => we do NOT touch pinned spans at all
    --    (so they keep the same fraction of v_total_weight as before).
    --    This is consistent with the approach that total_weight does not change.

    -- 9) Re-check total and correct rounding drift
    SELECT SUM(weight)
      INTO v_new_sum
      FROM span
     WHERE attribute_id = v_attr_id
       AND type = 'discrete';

    SET v_diff = v_total_weight - v_new_sum;

    IF v_diff != 0 THEN
        -- We'll just add or subtract the difference from the target span to keep
        -- the total the same. Another strategy might be to distribute it among 
        -- all unpinned spans proportionally, but this is simpler.
        UPDATE span
           SET weight = weight + v_diff
         WHERE id = in_span_id;
    END IF;

END$$
DELIMITER ;





