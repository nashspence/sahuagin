CREATE TABLE `attribute` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `type` ENUM('discrete', 'continuous') NOT NULL,
    `decimals` INT NULL,
    `has_labels` BOOLEAN NULL,
    `has_value` BOOLEAN NULL,
    `max_value` DOUBLE NULL,
    `min_value` DOUBLE NULL,
    `normal_value` DOUBLE NULL,
    `percent_normal` DOUBLE NULL,
    `percent_pinned` DOUBLE NULL,
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
    `weight` DOUBLE NULL,
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
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY
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
    `name` VARCHAR(255) NOT NULL,
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
CREATE TABLE `entity_varattr_value` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `entity_id` INT UNSIGNED NOT NULL,
    `numeric_value` DOUBLE,
    `span_id` INT UNSIGNED NOT NULL,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    `variant_attr_span_id` INT UNSIGNED,
    `label` VARCHAR(255),
    `units` VARCHAR(255),
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_evav_entity` FOREIGN KEY (`entity_id`) REFERENCES `entity` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_evav_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_evav_variant_attr` FOREIGN KEY (`variant_attribute_id`) REFERENCES `variant_attribute` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_evav_varattr_span` FOREIGN KEY (`variant_attr_span_id`) REFERENCES `variant_attr_span` (`id`) ON DELETE CASCADE,
); -- short for entity_variant_attribute_value

-- stored procedures

CREATE PROCEDURE get_page(
    IN p_tableName VARCHAR(64),          -- e.g. 'span'
    IN p_filterColumn VARCHAR(64),       -- e.g. 'attributeId'
    IN p_filterValue INT,                -- e.g. 123
    IN p_keyColumn VARCHAR(64),          -- e.g. 'id'
    IN p_direction VARCHAR(5),           -- 'before' or 'after'
    IN p_startKey INT,                   -- e.g. 50
    IN p_limit INT,                      -- e.g. 10
    IN p_commitHash VARCHAR(64)          -- optional commit hash
)
BEGIN
    DECLARE v_subQuery TEXT;
    DECLARE v_innerQuery TEXT;
    DECLARE v_whereClause VARCHAR(200);
    DECLARE v_orderClause VARCHAR(200);

    -- Choose the operator and ordering based on p_direction
    IF p_direction = 'after' THEN
        -- id > p_startKey, final sort ascending
        SET v_whereClause = CONCAT(p_keyColumn, ' > ?');
        SET v_orderClause = CONCAT('ORDER BY ', p_keyColumn, ' ASC LIMIT ?');
    ELSE
        -- id < p_startKey, but final ascending means we do a subselect
        SET v_whereClause = CONCAT(p_keyColumn, ' < ?');
        SET v_orderClause = CONCAT('ORDER BY ', p_keyColumn, ' DESC LIMIT ?');
    END IF;

    -- Decide whether to use AS OF
    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
        SET v_subQuery = CONCAT(
            'SELECT * FROM ', p_tableName,
            ' AS OF ''', p_commitHash, ''''    -- must be literal
        );
    ELSE
        SET v_subQuery = CONCAT(
            'SELECT * FROM ', p_tableName
        );
    END IF;

    -- Build the inner SELECT
    SET v_innerQuery = CONCAT(
        v_subQuery,
        ' WHERE ', p_filterColumn, ' = ? ',
        ' AND ', v_whereClause, ' ',
        v_orderClause
    );

    -- If direction = 'after', we can just run the inner query
    -- If direction = 'before', we do the "subselect + flip + re-sort"
    IF p_direction = 'after' THEN
        SET @finalQuery = v_innerQuery;
    ELSE
        -- subselect: we select in DESC order, limit, then reorder ASC in the outer query
        SET @finalQuery = CONCAT(
            'SELECT * FROM (', v_innerQuery, ') AS t ORDER BY t.', p_keyColumn, ' ASC'
        );
    END IF;

    -- Prepare and execute
    PREPARE stmt FROM @finalQuery;

    -- We have three parameters in the WHERE clause (the filter value, the startKey, the limit).
    -- The order in EXECUTE stmt USING must match the order of the '?' placeholders above.
    EXECUTE stmt USING p_filterValue, p_startKey, p_limit;

    DEALLOCATE PREPARE stmt;
END;

CREATE PROCEDURE get_targetable_varattr_for_variation_page (
    IN  p_vavs_id INT,
    IN  p_va_id INT,
    IN  p_variant_id INT,
    IN  p_causation_index INT,
    IN  p_limit INT,
    IN  p_direction VARCHAR(6),    -- 'after' or 'before'
    IN  p_commitHash VARCHAR(64)   -- for Dolt: optional commit hash
)
BEGIN
    -------------------------------------------------------------------
    -- A: Build "table references" depending on p_commitHash
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
    -- B: WITH RECURSIVE portion
    -------------------------------------------------------------------
    -- The logic is:
    --   1) Anchor: pick the given variant_attribute (p_va_id),
    --      plus optional joins for p_vavs_id & vavspan_attr.
    --   2) "Downward" recursion: from a node with Direction=1
    --      to children in the same variant_id that have a bigger causation_index.
    --   3) "Upward" recursion: from a node’s parent (via parentVariantId) if it has a smaller causation_index,
    --      switch Direction to 2.
    -------------------------------------------------------------------
    SET @cte_part = CONCAT(
        'WITH RECURSIVE VariantAttributeTraversal AS (',
        '  -- Anchor row: from the chosen variant_attribute p_va_id',
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

        '  -- Downward recursion (Direction=1): ',
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

        '  -- Upward recursion: switch to Direction=2. ',
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
    -- D: WHERE / ORDER based on p_direction
    -------------------------------------------------------------------
    IF p_direction = 'after' THEN
        -- "Forward" pagination
        SET @where_clause = CONCAT(
            'WHERE Direction = 2 ',
            '  AND (variantId > ? ',
            '       OR (variantId = ? AND variantAttributeIndex > ?)) '
        );
        SET @order_clause = 'ORDER BY variantId ASC, variantAttributeIndex ASC LIMIT ?';

        SET @full_query = CONCAT(@cte_part, @base_select, ' ', @where_clause, ' ', @order_clause);

    ELSE
        -- "before" pagination: we first gather in descending order, then flip ascending
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
            'SELECT * ',
            'FROM (', @inner_query, ') AS tmp ',
            'ORDER BY tmp.variantId ASC, tmp.variantAttributeIndex ASC'
        );
    END IF;

    -------------------------------------------------------------------
    -- E: Prepare & Execute the dynamic SQL
    -------------------------------------------------------------------
    SET @p_variant_id      = p_variant_id;
    SET @p_causation_index = p_causation_index;
    SET @p_limit           = p_limit;

    PREPARE stmt FROM @full_query;

    -- We have 4 placeholders in both cases:
    --   1) p_variant_id
    --   2) p_variant_id
    --   3) p_causation_index
    --   4) p_limit
    EXECUTE stmt USING @p_variant_id, @p_variant_id, @p_causation_index, @p_limit;

    DEALLOCATE PREPARE stmt;
END;

CREATE PROCEDURE pick_discrete_span_with_variations (
    IN p_variantAttributeId INT UNSIGNED,
    IN p_variantAttrVariantSpanId INT UNSIGNED,
    IN p_lower DOUBLE,
    IN p_upper DOUBLE,
    IN p_excludeSpanId INT UNSIGNED,
    IN p_commitHash VARCHAR(64)  -- optional commit hash for Dolt
)
BEGIN
    -------------------------------------------------------------------------
    -- 1) Build dynamic "AS OF" references if p_commitHash is given
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
        -- No commit hash => current HEAD
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
    -- 2) Build the query with CTEs (using window functions).
    --
    --    We'll do:
    --      - BaseSpans
    --      - ActiveVariations
    --      - InactiveSpans
    --      - ActivatedSpans
    --      - DeltaWeights
    --      - AllRelevantSpans (combine base & activated, exclude inactivated)
    --      - FinalSpans (apply sum of delta weights)
    --      - OrderedSpans (compute running total)
    --    Finally select the row covering p_lower..p_upper
    -------------------------------------------------------------------------
    SET @sql = CONCAT(
        'WITH ',
        'BaseSpans AS (',
        '   SELECT',
        '       s.id AS span_id,',
        '       va.id AS variant_attribute_id,',
        '       vas.id AS variant_attr_span_id,',
        '       s.weight AS base_weight',
        '   FROM ', v_table_va, ' va',
        '   JOIN ', v_table_span, ' s',
        '       ON s.attribute_id = va.attribute_id',
        '   LEFT JOIN ', v_table_vas, ' vas',
        '       ON vas.variant_attribute_id = va.id',
        '      AND vas.span_id = s.id',
        '   WHERE va.id = ?',
        '     AND s.type = ''discrete''',
        '     AND (',
        '         ? IS NULL OR ? = 0 OR s.id <> ?',
        '     )',
        '     AND (',
        '         ? IS NULL OR s.id IN (',
        '             SELECT s2.id',
        '             FROM ', v_table_span, ' s2',
        '             JOIN ', v_table_vas, ' vas2',
        '               ON vas2.span_id = s2.id',
        '              AND vas2.variant_attribute_id = va.id',
        '             WHERE vas2.id = ?',
        '         ) OR ? IS NULL',
        '     )',
        '),',

        'ActiveVariations AS (',
        '   SELECT v.id AS variation_id,',
        '          vav.variant_attribute_id',
        '   FROM ', v_table_variation, ' v',
        '   JOIN ', v_table_vavspan, ' vav',
        '     ON vav.id = v.to_modify_vavspan_attr_id',
        '    AND vav.variant_attribute_id = ?',
        '   WHERE v.is_inactive = 0',
        '),',

        'InactiveSpans AS (',
        '   SELECT DISTINCT vis.span_id',
        '   FROM ', v_table_var_inactive, ' vis',
        '   JOIN ActiveVariations av',
        '     ON av.variation_id = vis.variation_id',
        '),',

        'ActivatedSpans AS (',
        '   SELECT DISTINCT',
        '       vas.span_id,',
        '       av.variant_attribute_id,',
        '       NULL AS variant_attr_span_id,',
        '       0.0  AS base_weight',
        '   FROM ', v_table_var_activated, ' vas',
        '   JOIN ActiveVariations av',
        '     ON av.variation_id = vas.variation_id',
        '),',

        'DeltaWeights AS (',
        '   SELECT vdw.span_id, SUM(vdw.delta_weight) AS total_delta',
        '   FROM ', v_table_var_delta, ' vdw',
        '   JOIN ActiveVariations av',
        '     ON av.variation_id = vdw.variation_id',
        '   GROUP BY vdw.span_id',
        '),',

        '-- Combine base & activated, excluding any that appear in InactiveSpans',
        'AllRelevantSpans AS (',
        '   SELECT b.span_id, b.variant_attribute_id, b.variant_attr_span_id, b.base_weight',
        '   FROM BaseSpans b',
        '   WHERE b.span_id NOT IN (SELECT span_id FROM InactiveSpans)',
        '   UNION',
        '   SELECT a.span_id, a.variant_attribute_id, a.variant_attr_span_id, a.base_weight',
        '   FROM ActivatedSpans a',
        '   WHERE a.span_id NOT IN (SELECT span_id FROM InactiveSpans)',
        '),',

        'FinalSpans AS (',
        '   SELECT',
        '       ars.span_id,',
        '       ars.variant_attribute_id,',
        '       ars.variant_attr_span_id,',
        '       COALESCE(ars.base_weight, 0) + COALESCE(dw.total_delta, 0) AS effective_weight',
        '   FROM AllRelevantSpans ars',
        '   LEFT JOIN DeltaWeights dw ON dw.span_id = ars.span_id',
        '),',

        'OrderedSpans AS (',
        '   SELECT',
        '       fs.span_id,',
        '       fs.variant_attribute_id,',
        '       fs.variant_attr_span_id,',
        '       fs.effective_weight AS contextualWeight,',
        '       SUM(fs.effective_weight) OVER (ORDER BY fs.span_id',
        '           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW',
        '       ) AS runningTotal,',
        '       LAG(',
        '           SUM(fs.effective_weight) OVER (ORDER BY fs.span_id',
        '               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW',
        '           ),',
        '           1, 0',
        '       ) OVER (',
        '           ORDER BY fs.span_id',
        '       ) AS prevRunningTotal',
        '   FROM FinalSpans fs',
        '   WHERE fs.effective_weight > 0',
        '   ORDER BY fs.span_id',
        ')',

        'SELECT *',
        'FROM OrderedSpans',
        'WHERE ? > prevRunningTotal',
        '  AND ? <= runningTotal'
    );

    -------------------------------------------------------------------------
    -- Explanation of placeholders:
    --   1) p_variantAttributeId    -> used in BaseSpans (WHERE va.id=?)
    --   2) p_excludeSpanId         -> used in BaseSpans for "exclude" logic
    --   3) p_excludeSpanId         -> same
    --   4) p_excludeSpanId         -> same
    --   5) p_variantAttrVariantSpanId -> used in BaseSpans to force matching that vas
    --   6) p_variantAttrVariantSpanId -> same
    --   7) p_variantAttrVariantSpanId -> same
    --   8) p_variantAttributeId    -> used in ActiveVariations
    --   9) p_lower
    --   10) p_upper
    --
    -- The big string references them in the correct order. 
    -- We will EXECUTE using that order.
    -------------------------------------------------------------------------

    PREPARE stmt FROM @sql;
    EXECUTE stmt USING
        @p_vaId := p_variantAttributeId,      -- (1)
        @p_excl1 := p_excludeSpanId,          -- (2)
        @p_excl2 := p_excludeSpanId,          -- (3)
        @p_excl3 := p_excludeSpanId,          -- (4)
        @p_vavsid1 := p_variantAttrVariantSpanId,  -- (5)
        @p_vavsid2 := p_variantAttrVariantSpanId,  -- (6)
        @p_vavsid3 := p_variantAttrVariantSpanId,  -- (7)
        @p_vaId2 := p_variantAttributeId,     -- (8)
        @p_lower := p_lower,                  -- (9)
        @p_upper := p_upper;                  -- (10)

    DEALLOCATE PREPARE stmt;
END;

CREATE PROCEDURE pick_continuous_span_with_variations (
    IN p_variantAttributeId INT UNSIGNED,
    IN p_random DOUBLE,           -- expected in [0,1) 
    IN p_excludeSpanId INT UNSIGNED,
    IN p_commitHash VARCHAR(64)   -- optional for Dolt: commit hash
)
BEGIN
    -------------------------------------------------------------------------
    -- A) Build dynamic references based on optional commitHash
    -------------------------------------------------------------------------
    DECLARE v_table_va           VARCHAR(200);
    DECLARE v_table_span         VARCHAR(200);
    DECLARE v_table_variation    VARCHAR(200);
    DECLARE v_table_vavspan      VARCHAR(200);
    DECLARE v_table_var_cont     VARCHAR(200);

    IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
        SET v_table_va        = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
        SET v_table_span      = CONCAT('span AS OF ''', p_commitHash, '''');
        SET v_table_variation = CONCAT('variation AS OF ''', p_commitHash, '''');
        SET v_table_vavspan   = CONCAT('vavspan_attr AS OF ''', p_commitHash, '''');
        SET v_table_var_cont  = CONCAT('variation_continuous_attr AS OF ''', p_commitHash, '''');
    ELSE
        SET v_table_va        = 'variant_attribute';
        SET v_table_span      = 'span';
        SET v_table_variation = 'variation';
        SET v_table_vavspan   = 'vavspan_attr';
        SET v_table_var_cont  = 'variation_continuous_attr';
    END IF;

    -------------------------------------------------------------------------
    -- B) Build a query with CTEs that:
    --    1) Collects base continuous spans for p_variantAttributeId
    --    2) Finds "active" variations for that attribute (is_inactive=0)
    --    3) Sums up all delta_normal, delta_percent_normal, etc.
    --    4) Applies those deltas to each span's min/max => "effective" intervals
    --    5) Orders them by span_id, computes running total of (effective_max - effective_min)
    --    6) Picks the single interval that includes (p_random * total_sum_of_lengths)
    -------------------------------------------------------------------------
    -- We'll do a "template" approach that lumps all variations' continuous 
    -- deltas together. You might need more complex logic if variations 
    -- can selectively target *some* spans but not others.
    -------------------------------------------------------------------------

    SET @sql = CONCAT(
    'WITH ',

    'BaseSpans AS (',
    '    SELECT',
    '        s.id AS span_id,',
    '        va.id AS variant_attribute_id,',
    '        s.min_value AS base_min_value,',
    '        s.max_value AS base_max_value',
    '    FROM ', v_table_va, ' va',
    '    JOIN ', v_table_span, ' s',
    '        ON s.attribute_id = va.attribute_id',
    '    WHERE va.id = ?',
    '      AND s.type = ''continuous''',
    '      AND (',
    '          ? IS NULL OR ? = 0 OR s.id <> ?  -- exclude a particular span if needed',
    '      )',
    '),',

    'ActiveVariations AS (',
    '    SELECT v.id AS variation_id, v.is_inactive',
    '    FROM ', v_table_variation, ' v',
    '    JOIN ', v_table_vavspan, ' vav',
    '        ON vav.id = v.to_modify_vavspan_attr_id',
    '       AND vav.variant_attribute_id = ?',
    '    WHERE v.is_inactive = 0',
    '),',

    '-- Summation of all variation_continuous_attr deltas for the attribute. ',
    '-- If multiple variations are active, we sum them. Adjust logic if you want ',
    '-- separate sets of intervals or partial application.',
    'SummedContinuousDelta AS (',
    '    SELECT',
    '       COALESCE(SUM(vca.delta_normal),0)           AS total_delta_normal,',
    '       COALESCE(SUM(vca.delta_percent_normal),0)   AS total_delta_pnormal,',
    '       COALESCE(SUM(vca.delta_percent_skewed),0)   AS total_delta_pskew',
    '    FROM ', v_table_var_cont, ' vca',
    '    JOIN ActiveVariations av ',
    '      ON av.variation_id = vca.variation_id',
    '),',

    '-- Apply the summed deltas to each span: as a sample formula, we do:',
    '--  effective_min = base_min_value + total_delta_normal',
    '--  effective_max = base_max_value + total_delta_normal',
    '--  Then optionally scale them by (1 + total_delta_pnormal) or (1 + total_delta_pskew).',
    '--  (In reality, you might apply them differently, e.g. shift normal_value, etc.)',
    'FinalSpans AS (',
    '    SELECT',
    '        bs.span_id,',
    '        bs.variant_attribute_id,',
    '        CASE WHEN scd.total_delta_pnormal <> 0 OR scd.total_delta_pskew <> 0 ',
    '             THEN (bs.base_min_value + scd.total_delta_normal)',
    '                  * (1 + scd.total_delta_pnormal + scd.total_delta_pskew)',
    '             ELSE (bs.base_min_value + scd.total_delta_normal) ',
    '        END AS effective_min_value,',
    '        CASE WHEN scd.total_delta_pnormal <> 0 OR scd.total_delta_pskew <> 0 ',
    '             THEN (bs.base_max_value + scd.total_delta_normal)',
    '                  * (1 + scd.total_delta_pnormal + scd.total_delta_pskew)',
    '             ELSE (bs.base_max_value + scd.total_delta_normal) ',
    '        END AS effective_max_value',
    '    FROM BaseSpans bs',
    '    CROSS JOIN SummedContinuousDelta scd  -- only 1 row typically',
    '),',

    '-- Now compute the length and the running sum of these intervals.',
    'OrderedSpans AS (',
    '    SELECT',
    '        fs.span_id,',
    '        fs.variant_attribute_id,',
    '        LEAST(fs.effective_min_value, fs.effective_max_value) AS eff_min,',
    '        GREATEST(fs.effective_min_value, fs.effective_max_value) AS eff_max,',
    '        GREATEST(fs.effective_max_value - fs.effective_min_value, 0) AS interval_length,',

    '        SUM( GREATEST(fs.effective_max_value - fs.effective_min_value, 0) ) ',
    '            OVER (ORDER BY fs.span_id ',
    '                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW',
    '                 ) AS runningTotal,',

    '        LAG( ',
    '            SUM( GREATEST(fs.effective_max_value - fs.effective_min_value, 0) ) ',
    '            OVER (ORDER BY fs.span_id ',
    '                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW',
    '                 ), 1, 0',
    '        ) ',
    '        OVER (ORDER BY fs.span_id) AS prevRunningTotal',

    '    FROM FinalSpans fs',
    '    ORDER BY fs.span_id',
    '),',

    '-- Determine total length across ALL intervals (the last row).',
    'TotalLength AS (',
    '    SELECT runningTotal AS grandTotal',
    '    FROM OrderedSpans',
    '    ORDER BY runningTotal DESC',
    '    LIMIT 1',
    '),',

    '-- Finally pick the single row whose [prevRunningTotal, runningTotal) ',
    '-- covers p_random * grandTotal. ',
    'Picked AS (',
    '    SELECT os.*, (SELECT grandTotal FROM TotalLength) AS grandTotal',
    '    FROM OrderedSpans os',
    '    WHERE (',
    '        ? * (SELECT grandTotal FROM TotalLength) ',
    '    ) >= os.prevRunningTotal',
    '      AND (',
    '        ? * (SELECT grandTotal FROM TotalLength) ',
    '    ) < os.runningTotal',
    '    LIMIT 1',
    ')',

    'SELECT',
    '    Picked.span_id,',
    '    Picked.variant_attribute_id,',
    '    Picked.eff_min,',
    '    Picked.eff_max,',
    '    Picked.prevRunningTotal,',
    '    Picked.runningTotal,',
    '    Picked.grandTotal,',

    '    -- OPTIONAL: also compute the actual numeric value we "picked".',
    '    ' -- Let fractionInInterval = (p_random * grandTotal - prevRunningTotal)',
    '    ', -- Then actualValue = eff_min + fractionInInterval
    '    CASE ',
    '      WHEN (Picked.grandTotal > 0) THEN ',
    '         (Picked.eff_min + ( (? * Picked.grandTotal - Picked.prevRunningTotal ) ))',
    '      ELSE Picked.eff_min  -- fallback if total=0',
    '    END AS chosen_value',

    'FROM Picked'
    );

    -------------------------------------------------------------------------
    -- C) Prepare and execute the dynamic SQL
    -------------------------------------------------------------------------
    PREPARE stmt FROM @sql;
    EXECUTE stmt USING
        @p_vaId := p_variantAttributeId,  -- for BaseSpans
        @p_exc1 := p_excludeSpanId,
        @p_exc2 := p_excludeSpanId,
        @p_exc3 := p_excludeSpanId,
        @p_vaId2 := p_variantAttributeId, -- for ActiveVariations
        @p_rand1 := p_random,             -- for the final pick
        @p_rand2 := p_random,             -- same
        @p_rand3 := p_random;             -- for the "chosen_value" calculation

    DEALLOCATE PREPARE stmt;
END;