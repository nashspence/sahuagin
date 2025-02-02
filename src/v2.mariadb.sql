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
    CONSTRAINT `fk_variant_attr_attr` FOREIGN KEY (`attribute_id`) REFERENCES `attribute` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_variant_attr_variant` FOREIGN KEY (`variant_id`) REFERENCES `variant` (`id`) ON DELETE CASCADE
);
CREATE TABLE `variant_attr_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    `variant_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_varattr_span_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_varattr_span_varattr` FOREIGN KEY (`variant_attribute_id`) REFERENCES `variant_attribute` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_varattr_span_variant` FOREIGN KEY (`variant_id`) REFERENCES `variant` (`id`) ON DELETE CASCADE
); -- short for variant_attribute_variant_span
CREATE TABLE `vavspan_attr` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    `variant_attr_span_id` INT UNSIGNED,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_vavspan_attr_va` FOREIGN KEY (`variant_attribute_id`) REFERENCES `variant_attribute` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_vavspan_attr_vas` FOREIGN KEY (`variant_attr_span_id`) REFERENCES `variant_attr_span` (`id`) ON DELETE CASCADE
); -- short for variant_attribute_variant_span_variant_attribute
CREATE TABLE `variation` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `activating_span_id` INT UNSIGNED NOT NULL,
    `to_modify_vavspan_attr_id` INT UNSIGNED NOT NULL,
    `activating_vavspan_attr_id` INT UNSIGNED NOT NULL,
    `is_inactive` BOOLEAN NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_variation_span` FOREIGN KEY (`activating_span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_variation_vavspan_to_modify` FOREIGN KEY (`to_modify_vavspan_attr_id`) REFERENCES `vavspan_attr` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_variation_vavspan_activating` FOREIGN KEY (`activating_vavspan_attr_id`) REFERENCES `vavspan_attr` (`id`) ON DELETE CASCADE
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
    CONSTRAINT `fk_var_activated_span_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_var_activated_span_var` FOREIGN KEY (`variation_id`) REFERENCES `variation` (`id`) ON DELETE CASCADE
);
CREATE TABLE `variation_delta_weight` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `delta_weight` DOUBLE NOT NULL,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_delta_weight_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_var_delta_weight_var` FOREIGN KEY (`variation_id`) REFERENCES `variation` (`id`) ON DELETE CASCADE
);
CREATE TABLE `variation_inactive_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_inactive_span_span` FOREIGN KEY (`span_id`) REFERENCES `span` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_var_inactive_span_var` FOREIGN KEY (`variation_id`) REFERENCES `variation` (`id`) ON DELETE CASCADE
);
CREATE TABLE `entity` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variant_id` INT UNSIGNED NOT NULL,
    `commit_hash` CHAR(32) NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_entity_variant` FOREIGN KEY (`variant_id`) REFERENCES `variant` (`id`) ON DELETE CASCADE
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
CREATE TABLE `evav_lock` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `locked_evav_id` INT UNSIGNED NOT NULL,
    `locking_evav_id` INT UNSIGNED,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_evav_lock_locked_evav` FOREIGN KEY (`locked_evav_id`) REFERENCES `entity_varattr_value` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_evav_lock_locking_evav` FOREIGN KEY (`locking_evav_id`) REFERENCES `entity_varattr_value` (`id`) ON DELETE CASCADE
); -- short for entity_variant_attribute_value_lock




CREATE INDEX idx_attribute_name ON attribute(name);

CREATE INDEX idx_span_attribute_id ON span(attribute_id);
CREATE INDEX idx_span_attribute_type ON span(attribute_id, type, id);
CREATE INDEX idx_span_attr_type ON span(attribute_id, type, min_value, max_value);
CREATE INDEX idx_span_attr_type_pinned ON span(attribute_id, type, is_percentage_pinned);
CREATE INDEX idx_span_attr_type_pinned_wl ON span(attribute_id, type, is_percentage_pinned, weight, label);

CREATE INDEX idx_variant_name ON variant(name);

CREATE INDEX idx_variant_attribute_attribute ON variant_attribute(attribute_id);
CREATE INDEX idx_variant_attribute_variant ON variant_attribute(variant_id);
CREATE INDEX idx_variant_attribute_variant_causation ON variant_attribute(variant_id, causation_index);

CREATE INDEX idx_variant_attr_span_span_id ON variant_attr_span(span_id);
CREATE INDEX idx_variant_attr_span_variant_attribute_id ON variant_attr_span(variant_attribute_id);
CREATE INDEX idx_variant_attr_span_variant_attr ON variant_attr_span(variant_id, variant_attribute_id);
CREATE INDEX idx_variant_attr_span_vaid_spanid ON variant_attr_span(variant_attribute_id, span_id);
CREATE INDEX idx_variant_attr_span_vaid_variant ON variant_attr_span(variant_attribute_id, variant_id);

CREATE INDEX idx_vavspan_attr_variant_attribute ON vavspan_attr(variant_attribute_id);
CREATE INDEX idx_vavspan_attr_vaid ON vavspan_attr(variant_attribute_id, id);
CREATE INDEX idx_uq_vavspan_attr ON vavspan_attr(variant_attribute_id, variant_attr_span_id);

CREATE INDEX idx_var_cont_variation ON variation_continuous_attr(variation_id);

CREATE INDEX idx_variation_activated_span_varid_spanid ON variation_activated_span(variation_id, span_id);

CREATE INDEX idx_variation_inactive ON variation_inactive_span(variation_id, span_id);

CREATE INDEX idx_variation_delta_weight_varid_spanid ON variation_delta_weight(variation_id, span_id);
CREATE INDEX idx_variation_delta ON variation_delta_weight(variation_id, span_id, delta_weight);

CREATE INDEX idx_variation_is_inactive ON variation(is_inactive, id);
CREATE INDEX idx_variation_to_modify_inactive ON variation(to_modify_vavspan_attr_id, is_inactive);

CREATE INDEX idx_entity_commithash ON entity(commit_hash);

CREATE INDEX idx_entity_state_entity_id ON entity_state(entity_id);
CREATE INDEX idx_entity_state_entity_time ON entity_state(entity_id, time);

CREATE INDEX idx_entity_varattr_value_entity_state_id ON entity_varattr_value(entity_state_id);
CREATE INDEX idx_evav_state_vaid ON entity_varattr_value(entity_state_id, variant_attribute_id);
CREATE INDEX idx_evav_state_attr_span ON entity_varattr_value(entity_state_id, variant_attribute_id, span_id);

CREATE INDEX idx_evav_lock_locked ON evav_lock(locked_evav_id);
CREATE INDEX idx_evav_lock_locking ON evav_lock(locking_evav_id);
CREATE INDEX idx_evav_lock_locked_locking ON evav_lock(locked_evav_id, locking_evav_id);




DELIMITER $$
CREATE PROCEDURE get_forward_attr_options_page (
    IN  p_vavs_id INT,
    IN  p_va_id INT,
    IN  p_variant_id INT,
    IN  p_causation_index INT,
    IN  p_limit INT,
    IN  p_direction VARCHAR(6),    -- 'after' or 'before'
    IN  p_commitHash VARCHAR(64)     -- optional Dolt commit hash
)
BEGIN
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

    SET @cte = CONCAT(
      'WITH RECURSIVE VariantAttributeTraversal AS ( ',
      '  SELECT va.id AS variantAttributeId, ',
      '         va.causation_index, ',
      '         va.variant_id AS variantId, ',
      '         vavs.id AS variantAttributeVariantSpanId, ',
      '         cva.id AS variantAttributeVariantSpanVariantAttributeId, ',
      '         vavs.variant_id AS parentVariantId, ',
      '         1 AS Direction ',
      '  FROM ', v_table_va, ' AS va ',
      '  LEFT JOIN ', v_table_vas, ' AS vavs ON va.id = vavs.variant_attribute_id AND vavs.id = ', p_vavs_id, ' ',
      '  LEFT JOIN ', v_table_vavspan, ' AS cva ON va.id = cva.variant_attribute_id ',
      '  WHERE va.id = ', p_va_id, ' ',
      '  UNION ALL ',
      '  SELECT va_sub.id, ',
      '         va_sub.causation_index, ',
      '         va_sub.variant_id, ',
      '         vavs_sub.id, ',
      '         cva_sub.id, ',
      '         vavs_sub.variant_id, ',
      '         vat.Direction ',
      '  FROM VariantAttributeTraversal AS vat ',
      '  JOIN ', v_table_vas, ' AS vavs_sub ON vat.variantId = vavs_sub.variant_id ',
      '  JOIN ', v_table_va, ' AS va_sub ON vavs_sub.variant_attribute_id = va_sub.id AND vat.causation_index < va_sub.causation_index ',
      '  LEFT JOIN ', v_table_vavspan, ' AS cva_sub ON va_sub.id = cva_sub.variant_attribute_id ',
      '  WHERE vat.Direction = 1 ',
      '  UNION ALL ',
      '  SELECT va_parent.id, ',
      '         va_parent.causation_index, ',
      '         va_parent.variant_id, ',
      '         vavs_parent.id, ',
      '         cva_parent.id, ',
      '         vavs_parent.variant_id, ',
      '         2 AS Direction ',
      '  FROM VariantAttributeTraversal AS vat ',
      '  JOIN ', v_table_vas, ' AS vavs_parent ON vat.parentVariantId = vavs_parent.variant_id ',
      '  JOIN ', v_table_va, ' AS va_parent ON vavs_parent.variant_attribute_id = va_parent.id AND vat.causation_index > va_parent.causation_index ',
      '  LEFT JOIN ', v_table_vavspan, ' AS cva_parent ON va_parent.id = cva_parent.variant_attribute_id ',
      ') '
    );

    SET @baseSelect = 
      'SELECT variantAttributeId, variantId, causation_index AS variantAttributeIndex, '  ||
      '       variantAttributeVariantSpanVariantAttributeId, variantAttributeVariantSpanId '  ||
      'FROM VariantAttributeTraversal ';

    IF p_direction = 'after' THEN
        SET @whereOrder = 
          'WHERE Direction = 2 AND (variantId > ? OR (variantId = ? AND variantAttributeIndex > ?)) ' ||
          'ORDER BY variantId ASC, variantAttributeIndex ASC LIMIT ?';
        SET @sql = CONCAT(@cte, @baseSelect, @whereOrder);
    ELSE
        SET @innerQuery = CONCAT(
            @baseSelect,
            'WHERE Direction = 2 AND (variantId < ? OR (variantId = ? AND variantAttributeIndex < ?)) ',
            'ORDER BY variantId DESC, variantAttributeIndex DESC LIMIT ?'
        );
        SET @sql = CONCAT(@cte,
            'SELECT * FROM (', @innerQuery, ') AS tmp ',
            'ORDER BY tmp.variantId ASC, tmp.variantAttributeIndex ASC'
        );
    END IF;

    SET @p_variant_id      = p_variant_id;
    SET @p_causation_index = p_causation_index;
    SET @p_limit           = p_limit;

    PREPARE stmt FROM @sql;
    EXECUTE stmt USING @p_variant_id, @p_variant_id, @p_causation_index, @p_limit;
    DEALLOCATE PREPARE stmt;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE get_span_options_page (
    IN p_va_id INT,
    IN p_cursor_weight DOUBLE,
    IN p_cursor_id INT,
    IN p_limit INT,
    IN p_direction VARCHAR(6),  -- 'after' or 'before'
    IN p_commitHash VARCHAR(64) -- optional commit hash
)
BEGIN
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

    -- Base query: spans directly linked to the variant_attribute
    SET @base_query = CONCAT(
        'SELECT s.id AS spanId, s.label, s.weight AS effective_weight, ''base'' AS source ',
        'FROM ', v_table_span, ' s ',
        'JOIN ', v_table_vas, ' vas ON s.id = vas.span_id ',
        'WHERE vas.variant_attribute_id = ? '
    );

    -- Variation query: spans activated via a variation
    SET @variation_query = CONCAT(
        'SELECT s.id AS spanId, s.label, (s.weight + COALESCE(vdw.delta_weight, 0)) AS effective_weight, ''variation'' AS source ',
        'FROM ', v_table_var_act, ' vas_act ',
        'JOIN ', v_table_variation, ' v ON vas_act.variation_id = v.id AND v.is_inactive = 0 ',
        'JOIN ', v_table_vavspan, ' vav ON v.to_modify_vavspan_attr_id = vav.id AND vav.variant_attribute_id = ? ',
        'JOIN ', v_table_span, ' s ON vas_act.span_id = s.id ',
        'LEFT JOIN ', v_table_var_delta, ' vdw ON v.id = vdw.variation_id AND s.id = vdw.span_id '
    );

    SET @union_query = CONCAT('(', @base_query, ') UNION ALL (', @variation_query, ')');

    IF p_direction = 'after' THEN
        SET @pagination_where = 'WHERE (effective_weight > ? OR (effective_weight = ? AND spanId > ?)) ';
        SET @order_clause = 'ORDER BY effective_weight ASC, spanId ASC ';
    ELSE
        SET @pagination_where = 'WHERE (effective_weight < ? OR (effective_weight = ? AND spanId < ?)) ';
        SET @order_clause = 'ORDER BY effective_weight DESC, spanId DESC ';
    END IF;

    SET @limit_clause = 'LIMIT ?';

    SET @full_query = CONCAT(
        'SELECT * FROM (', @union_query, ') t ',
        @pagination_where,
        @order_clause,
        @limit_clause
    );

    -- Bind parameters in order:
    --   1. p_va_id (base query)
    --   2. p_va_id (variation query)
    --   3. p_cursor_weight, 4. p_cursor_weight, 5. p_cursor_id (pagination)
    --   6. p_limit (limit)
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
    IN  p_variantAttributeId      INT UNSIGNED,
    IN  p_variantAttrVariantSpanId  INT UNSIGNED,
    IN  p_excludeSpanId           INT UNSIGNED,
    IN  p_commitHash              VARCHAR(64)
)
proc_begin: BEGIN
  -- Build dynamic table names (for AS OF queries)
  DECLARE v_table_va           VARCHAR(200);
  DECLARE v_table_vas          VARCHAR(200);
  DECLARE v_table_span         VARCHAR(200);
  DECLARE v_table_vavspan      VARCHAR(200);
  DECLARE v_table_variation    VARCHAR(200);
  DECLARE v_table_var_inactive VARCHAR(200);
  DECLARE v_table_var_activated VARCHAR(200);
  DECLARE v_table_var_delta    VARCHAR(200);
  DECLARE v_totalWeight        DOUBLE DEFAULT 0;
  DECLARE v_randomPick         DOUBLE DEFAULT 0;
  DECLARE v_span_id            INT UNSIGNED DEFAULT NULL;
  DECLARE sql_stmt             TEXT;
  
  IF p_commitHash IS NOT NULL AND p_commitHash <> '' THEN
    SET v_table_va            = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
    SET v_table_vas           = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
    SET v_table_span          = CONCAT('span AS OF ''', p_commitHash, '''');
    SET v_table_vavspan       = CONCAT('vavspan_attr AS OF ''', p_commitHash, '''');
    SET v_table_variation     = CONCAT('variation AS OF ''', p_commitHash, '''');
    SET v_table_var_inactive  = CONCAT('variation_inactive_span AS OF ''', p_commitHash, '''');
    SET v_table_var_activated = CONCAT('variation_activated_span AS OF ''', p_commitHash, '''');
    SET v_table_var_delta     = CONCAT('variation_delta_weight AS OF ''', p_commitHash, '''');
  ELSE
    SET v_table_va            = 'variant_attribute';
    SET v_table_vas           = 'variant_attr_span';
    SET v_table_span          = 'span';
    SET v_table_vavspan       = 'vavspan_attr';
    SET v_table_variation     = 'variation';
    SET v_table_var_inactive  = 'variation_inactive_span';
    SET v_table_var_activated = 'variation_activated_span';
    SET v_table_var_delta     = 'variation_delta_weight';
  END IF;
  
  -- Build _OrderedSpans with candidate spans and cumulative weights
  DROP TEMPORARY TABLE IF EXISTS _OrderedSpans;
  SET sql_stmt = CONCAT(
    'CREATE TEMPORARY TABLE _OrderedSpans AS WITH BaseSpans AS (',
      'SELECT s.id AS span_id, va.id AS variant_attribute_id, vas.id AS variant_attr_span_id, s.weight AS base_weight ',
      'FROM ', v_table_va, ' va ',
      'JOIN ', v_table_span, ' s ON s.attribute_id = va.attribute_id ',
      'LEFT JOIN ', v_table_vas, ' vas ON vas.variant_attribute_id = va.id AND vas.span_id = s.id ',
      'WHERE va.id = ', p_variantAttributeId, ' AND s.type = ''discrete'' ',
      'AND (', p_excludeSpanId, ' = 0 OR s.id <> ', p_excludeSpanId, ') ',
      'AND s.id IN (',
          'SELECT s2.id FROM ', v_table_span, ' s2 ',
          'JOIN ', v_table_vas, ' vas2 ON vas2.span_id = s2.id AND vas2.variant_attribute_id = va.id ',
          'WHERE vas2.id = ', p_variantAttrVariantSpanId,
      ')',
    '), ActiveVariations AS (',
      'SELECT v.id AS variation_id, vav.variant_attribute_id ',
      'FROM ', v_table_variation, ' v ',
      'JOIN ', v_table_vavspan, ' vav ON vav.id = v.to_modify_vavspan_attr_id AND vav.variant_attribute_id = ', p_variantAttributeId, ' ',
      'WHERE v.is_inactive = 0',
    '), InactiveSpans AS (',
      'SELECT DISTINCT vis.span_id FROM ', v_table_var_inactive, ' vis ',
      'JOIN ActiveVariations av ON av.variation_id = vis.variation_id',
    '), ActivatedSpans AS (',
      'SELECT DISTINCT vas.span_id, av.variant_attribute_id, NULL AS variant_attr_span_id, 0.0 AS base_weight ',
      'FROM ', v_table_var_activated, ' vas ',
      'JOIN ActiveVariations av ON av.variation_id = vas.variation_id',
    '), DeltaWeights AS (',
      'SELECT vdw.span_id, SUM(vdw.delta_weight) AS total_delta ',
      'FROM ', v_table_var_delta, ' vdw ',
      'JOIN ActiveVariations av ON av.variation_id = vdw.variation_id ',
      'GROUP BY vdw.span_id',
    '), AllRelevantSpans AS (',
      'SELECT b.span_id, b.variant_attribute_id, b.variant_attr_span_id, b.base_weight ',
      'FROM BaseSpans b WHERE b.span_id NOT IN (SELECT span_id FROM InactiveSpans) ',
      'UNION ',
      'SELECT a.span_id, a.variant_attribute_id, a.variant_attr_span_id, a.base_weight ',
      'FROM ActivatedSpans a WHERE a.span_id NOT IN (SELECT span_id FROM InactiveSpans)',
    '), FinalSpans AS (',
      'SELECT ars.span_id, ars.variant_attribute_id, ars.variant_attr_span_id, ',
      'COALESCE(ars.base_weight,0) + COALESCE(dw.total_delta,0) AS effective_weight ',
      'FROM AllRelevantSpans ars LEFT JOIN DeltaWeights dw ON dw.span_id = ars.span_id',
    '), OrderedSpans AS (',
      'SELECT fs.span_id, fs.variant_attribute_id, fs.variant_attr_span_id, fs.effective_weight AS contextualWeight, ',
      'SUM(fs.effective_weight) OVER (ORDER BY fs.span_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS runningTotal, ',
      'LAG(SUM(fs.effective_weight) OVER (ORDER BY fs.span_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),1,0) OVER (ORDER BY fs.span_id) AS prevRunningTotal ',
      'FROM FinalSpans fs WHERE fs.effective_weight > 0 ORDER BY fs.span_id',
    ') SELECT * FROM OrderedSpans'
  );
  PREPARE stmt FROM sql_stmt;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
  
  -- Get total cumulative weight; if 0, return NULL.
  SELECT COALESCE(MAX(runningTotal), 0) INTO v_totalWeight FROM _OrderedSpans;
  IF v_totalWeight <= 0 THEN
    DROP TEMPORARY TABLE IF EXISTS _OrderedSpans;
    SELECT NULL AS selected_span_id;
    LEAVE proc_begin;
  END IF;
  
  -- Roll a random number and select the span where it lands.
  SET v_randomPick = FLOOR(RAND() * v_totalWeight);
  SELECT span_id INTO v_span_id FROM _OrderedSpans
    WHERE v_randomPick >= prevRunningTotal AND v_randomPick < runningTotal
    LIMIT 1;
  
  DROP TEMPORARY TABLE IF EXISTS _OrderedSpans;
  SELECT v_span_id AS selected_span_id;
END proc_begin $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE roll_continuous_varattr (
    IN p_variantAttributeId INT UNSIGNED,
    IN p_variantAttrVariantSpanId INT UNSIGNED,  -- now required
    IN p_excludeSpanId INT UNSIGNED,
    IN p_commitHash VARCHAR(64)
)
roll_cont_proc: BEGIN
    -- Set table references based on commit hash.
    DECLARE v_table_va, v_table_span, v_table_vas, v_table_variation, v_table_vavspan, v_table_var_cont VARCHAR(200);
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
    
    -- Retrieve the attribute details.
    DECLARE v_attributeId INT UNSIGNED;
    DECLARE v_decimals INT DEFAULT 0;
    DECLARE v_min, v_max, v_normal DOUBLE;
    DECLARE v_percentNormal, v_percentPinned, v_percentSkewed DOUBLE;
    
    SET @sql_attr = CONCAT(
      'SELECT @attribute_id := va.attribute_id, ',
      '       @decimals      := a.decimals, ',
      '       @min           := a.min_value, ',
      '       @max           := a.max_value, ',
      '       @normal        := a.normal_value, ',
      '       @percent_normal:= a.percent_normal, ',
      '       @percent_pinned:= a.percent_pinned, ',
      '       @percent_skewed:= a.percent_skewed ',
      'FROM ', v_table_va, ' va ',
      'JOIN attribute a ON a.id = va.attribute_id ',
      'WHERE va.id = ? LIMIT 1'
    );
    PREPARE stmt_attr FROM @sql_attr;
    SET @p_vaId = p_variantAttributeId;
    EXECUTE stmt_attr USING @p_vaId;
    DEALLOCATE PREPARE stmt_attr;
    
    SELECT @attribute_id, @decimals, @min, @max, @normal, @percent_normal, @percent_pinned, @percent_skewed
      INTO v_attributeId, v_decimals, v_min, v_max, v_normal, v_percentNormal, v_percentPinned, v_percentSkewed;
    
    IF v_attributeId IS NULL THEN
        SELECT 'No matching attribute found' AS error_message;
        LEAVE roll_cont_proc;
    END IF;
    
    -- Sum up all variation deltas for this attribute.
    DECLARE v_totalDeltaNormal, v_totalDeltaPnormal, v_totalDeltaPskew DOUBLE DEFAULT 0;
    SET @sql_summed = CONCAT(
      'SELECT @total_delta_normal := COALESCE(SUM(vca.delta_normal),0), ',
      '       @total_delta_pnormal:= COALESCE(SUM(vca.delta_percent_normal),0), ',
      '       @total_delta_pskew  := COALESCE(SUM(vca.delta_percent_skewed),0) ',
      'FROM ', v_table_var_cont, ' vca ',
      'JOIN (SELECT v.id FROM ', v_table_variation, ' v ',
      '      JOIN ', v_table_vavspan, ' vav ON vav.id = v.to_modify_vavspan_attr_id ',
      '      WHERE vav.variant_attribute_id = ? AND vav.id = ? AND v.is_inactive = 0) av ',
      'ON av.id = vca.variation_id'
    );
    PREPARE stmt_summed FROM @sql_summed;
    SET @p_vaId2    = p_variantAttributeId;
    SET @p_vavspanId= p_variantAttrVariantSpanId;
    EXECUTE stmt_summed USING @p_vaId2, @p_vavspanId;
    DEALLOCATE PREPARE stmt_summed;
    
    SELECT @total_delta_normal, @total_delta_pnormal, @total_delta_pskew
      INTO v_totalDeltaNormal, v_totalDeltaPnormal, v_totalDeltaPskew;
    
    -- Compute effective min, max and normal.
    DECLARE v_effMin, v_effMax, v_effNormal DOUBLE;
    IF (v_totalDeltaPnormal <> 0 OR v_totalDeltaPskew <> 0) THEN
        SET v_effMin    = (v_min + v_totalDeltaNormal) * (1 + v_totalDeltaPnormal + v_totalDeltaPskew);
        SET v_effMax    = (v_max + v_totalDeltaNormal) * (1 + v_totalDeltaPnormal + v_totalDeltaPskew);
        SET v_effNormal = (v_normal + v_totalDeltaNormal) * (1 + v_totalDeltaPnormal + v_totalDeltaPskew);
    ELSE
        SET v_effMin    = v_min + v_totalDeltaNormal;
        SET v_effMax    = v_max + v_totalDeltaNormal;
        SET v_effNormal = v_normal + v_totalDeltaNormal;
    END IF;
    IF v_effMax < v_effMin THEN
        DECLARE v_tmp DOUBLE;
        SET v_tmp = v_effMin;
        SET v_effMin = v_effMax;
        SET v_effMax = v_tmp;
    END IF;
    
    -- Generate a skewed random number.
    DECLARE v_totalDiscreteValues, v_randomUniform, v_midpoint, v_skewOffset, v_normalOffset DOUBLE;
    DECLARE v_degreeEstimate, v_discreteDegreeEstimate, v_cubicDegreeEstimate DOUBLE;
    DECLARE v_skewed, v_distributed, v_multiplier, v_offset, v_result, v_clampedResult DOUBLE;
    DECLARE v_mult, v_avg DOUBLE;
    
    SET v_totalDiscreteValues = (v_effMax - v_effMin) * POW(10, v_decimals) + 1;
    IF v_totalDiscreteValues < 1 THEN SET v_totalDiscreteValues = 1; END IF;
    SET v_randomUniform = RAND() * v_totalDiscreteValues;
    SET v_midpoint      = v_totalDiscreteValues / 2;
    SET v_skewOffset    = (-v_midpoint * IFNULL(v_percentSkewed, 0)) / 100;
    SET v_normalOffset  = v_effNormal - ((v_effMax - v_effMin) / 2) - v_effMin;
    IF v_percentNormal IS NULL OR v_percentNormal <= 0 THEN SET v_percentNormal = 0; END IF;
    SET v_degreeEstimate       = -2.3 / LN((v_percentNormal / 100) + 0.000052) - 0.5;
    SET v_mult                 = FLOOR(v_degreeEstimate / 0.04);
    SET v_discreteDegreeEstimate = v_degreeEstimate - (v_mult * 0.04);
    SET v_cubicDegreeEstimate  = 1 + 2 * v_discreteDegreeEstimate;
    SET v_skewed               = v_randomUniform - v_midpoint - v_skewOffset;
    SET v_distributed          = SIGN(v_skewed) * POW(ABS(v_skewed), v_cubicDegreeEstimate);
    IF (v_totalDiscreteValues - 2 * v_skewOffset * SIGN(v_skewed)) = 0 THEN
        SET v_multiplier = 0;
    ELSE
        SET v_multiplier = ((v_effMax - v_effMin) * POW(4, v_discreteDegreeEstimate))
                           / POW((v_totalDiscreteValues - 2 * v_skewOffset * SIGN(v_skewed)), v_cubicDegreeEstimate);
    END IF;
    SET v_avg    = (v_effMin + v_effMax) / 2;
    SET v_offset = ((-2 * v_normalOffset * v_multiplier * ABS(v_distributed)) / (v_effMax - v_effMin))
                   + v_normalOffset + v_avg;
    SET v_result = ROUND(v_multiplier * v_distributed + v_offset, v_decimals);
    IF v_result < v_effMin THEN
        SET v_clampedResult = v_effMin;
    ELSEIF v_result > v_effMax THEN
        SET v_clampedResult = v_effMax;
    ELSE
        SET v_clampedResult = v_result;
    END IF;
    
    -- Build span selection query (add exclusion if needed).
    DECLARE v_excludeClause VARCHAR(50) DEFAULT '';
    DECLARE v_hasExclude INT DEFAULT 0;
    IF p_excludeSpanId IS NOT NULL AND p_excludeSpanId <> 0 THEN
        SET v_excludeClause = ' AND s.id <> ?';
        SET v_hasExclude = 1;
    END IF;
    
    DECLARE v_chosenSpanId INT UNSIGNED DEFAULT NULL;
    SET @sql_span = CONCAT(
        'SELECT @span_id := s.id, ',
        '       CASE WHEN (? <> 0 OR ? <> 0) THEN (s.min_value + ?) * (1 + ? + ?) ELSE (s.min_value + ?) END AS eff_min, ',
        '       CASE WHEN (? <> 0 OR ? <> 0) THEN (s.max_value + ?) * (1 + ? + ?) ELSE (s.max_value + ?) END AS eff_max ',
        'FROM ', v_table_span, ' s ',
        'JOIN ', v_table_vas, ' vas ON vas.span_id = s.id ',
        'WHERE s.attribute_id = ? AND s.type = ''continuous''',
        v_excludeClause,
        ' AND vas.id = ? HAVING eff_min <= ? AND eff_max > ? LIMIT 1'
    );
    PREPARE stmt_span FROM @sql_span;
    -- Set parameters for the two versions (with or without the exclusion clause).
    IF v_hasExclude = 1 THEN
        SET @p1  = v_totalDeltaPnormal; SET @p2  = v_totalDeltaPskew; SET @p3  = v_totalDeltaNormal;
        SET @p4  = v_totalDeltaPnormal; SET @p5  = v_totalDeltaPskew; SET @p6  = v_totalDeltaNormal;
        SET @p7  = v_totalDeltaPnormal; SET @p8  = v_totalDeltaPskew; SET @p9  = v_totalDeltaNormal;
        SET @p10 = v_totalDeltaPnormal; SET @p11 = v_totalDeltaPskew; SET @p12 = v_totalDeltaNormal;
        SET @p13 = v_attributeId;
        SET @p14 = p_excludeSpanId;
        SET @p15 = p_variantAttrVariantSpanId;
        SET @p16 = v_clampedResult; SET @p17 = v_clampedResult;
        EXECUTE stmt_span USING
            @p1,@p2,@p3,@p4,@p5,@p6,
            @p7,@p8,@p9,@p10,@p11,@p12,
            @p13,@p14,@p15,@p16,@p17;
    ELSE
        SET @p1  = v_totalDeltaPnormal; SET @p2  = v_totalDeltaPskew; SET @p3  = v_totalDeltaNormal;
        SET @p4  = v_totalDeltaPnormal; SET @p5  = v_totalDeltaPskew; SET @p6  = v_totalDeltaNormal;
        SET @p7  = v_totalDeltaPnormal; SET @p8  = v_totalDeltaPskew; SET @p9  = v_totalDeltaNormal;
        SET @p10 = v_totalDeltaPnormal; SET @p11 = v_totalDeltaPskew; SET @p12 = v_totalDeltaNormal;
        SET @p13 = v_attributeId;
        SET @p14 = p_variantAttrVariantSpanId;
        SET @p15 = v_clampedResult; SET @p16 = v_clampedResult;
        EXECUTE stmt_span USING
            @p1,@p2,@p3,@p4,@p5,@p6,
            @p7,@p8,@p9,@p10,@p11,@p12,
            @p13,@p14,@p15,@p16;
    END IF;
    DEALLOCATE PREPARE stmt_span;
    
    SELECT @span_id AS span_id, v_clampedResult AS chosen_value;
END roll_cont_proc $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE generate_entity_state(
    IN  p_entity_id                    INT UNSIGNED,
    IN  p_time                         DOUBLE,
    IN  p_commitHash                   VARCHAR(64),
    IN  p_regenerate_entity_state_id   INT UNSIGNED
)
BEGIN
    -- Label the main block so we can exit early on error.
    generate_entity_state_proc: BEGIN
        DECLARE v_root_variant_id         INT UNSIGNED;
        DECLARE v_entity_state_id         INT UNSIGNED;
        DECLARE v_current_variant         INT UNSIGNED;
        DECLARE cur_va_id                 INT UNSIGNED;
        DECLARE cur_attr_type             ENUM('discrete','continuous');
        DECLARE v_variantAttrVariantSpanId INT UNSIGNED;
        DECLARE v_existing_evav_id        INT UNSIGNED DEFAULT NULL;
        DECLARE v_existing_span_id        INT UNSIGNED DEFAULT NULL;
        DECLARE v_lock_count              INT DEFAULT 0;
        DECLARE v_new_span_id             INT UNSIGNED;
        DECLARE v_new_numeric             DOUBLE;
        DECLARE v_used_span_id            INT UNSIGNED;
        DECLARE v_sub_variant_id          INT UNSIGNED;
        DECLARE done                      INT DEFAULT FALSE;
        DECLARE v_use_commit              TINYINT DEFAULT 0;

        SET v_use_commit = (p_commitHash IS NOT NULL AND p_commitHash <> '');

        -- 0) Get the root variant.
        IF v_use_commit THEN
            SET @tbl = CONCAT('entity AS OF ''', p_commitHash, '''');
            SET @sql = CONCAT('SELECT variant_id FROM ', @tbl, ' WHERE id = ? LIMIT 1');
            PREPARE stmt FROM @sql;
            SET @p_entity_id = p_entity_id;
            EXECUTE stmt USING @p_entity_id INTO v_root_variant_id;
            DEALLOCATE PREPARE stmt;
        ELSE
            SELECT variant_id 
              INTO v_root_variant_id 
              FROM entity 
             WHERE id = p_entity_id 
             LIMIT 1;
        END IF;

        IF v_root_variant_id IS NULL THEN
           SELECT CONCAT('No entity found with id=', p_entity_id) AS error_message;
           LEAVE generate_entity_state_proc;
        END IF;

        -- 1) Use supplied state id (regeneration) or insert a new entity_state.
        IF p_regenerate_entity_state_id IS NOT NULL THEN
            SET v_entity_state_id = p_regenerate_entity_state_id;
        ELSE
            INSERT INTO entity_state (entity_id, `time`)
            VALUES (p_entity_id, p_time);
            SET v_entity_state_id = LAST_INSERT_ID();
        END IF;

        -- 2) Create a temporary variant queue.
        DROP TEMPORARY TABLE IF EXISTS _VariantQueue;
        CREATE TEMPORARY TABLE _VariantQueue (
            variant_id INT UNSIGNED NOT NULL
        ) ENGINE=MEMORY;
        INSERT INTO _VariantQueue (variant_id) VALUES (v_root_variant_id);

        -- 3) Create a temporary table for variant attributes.
        DROP TEMPORARY TABLE IF EXISTS _VariantAttributes;
        CREATE TEMPORARY TABLE _VariantAttributes (
            va_id     INT UNSIGNED,
            attr_type ENUM('discrete','continuous')
        ) ENGINE=MEMORY;

        DECLARE va_cursor CURSOR FOR
            SELECT va_id, attr_type FROM _VariantAttributes;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

        WHILE (SELECT COUNT(*) FROM _VariantQueue) > 0 DO
            -- 3A) Pop one variant from the queue.
            SELECT variant_id INTO v_current_variant FROM _VariantQueue LIMIT 1;
            DELETE FROM _VariantQueue WHERE variant_id = v_current_variant LIMIT 1;

            -- 3B) Populate _VariantAttributes for the current variant.
            TRUNCATE TABLE _VariantAttributes;
            IF v_use_commit THEN
                SET @tbl_va = CONCAT('variant_attribute AS OF ''', p_commitHash, '''');
                SET @tbl_a  = CONCAT('attribute AS OF ''', p_commitHash, '''');
                SET @sql = CONCAT(
                    'INSERT INTO _VariantAttributes (va_id, attr_type) ',
                    'SELECT va.id, a.type FROM ', @tbl_va, ' va ',
                    'JOIN ', @tbl_a, ' a ON a.id = va.attribute_id ',
                    'WHERE va.variant_id = ?'
                );
                PREPARE stmt FROM @sql;
                SET @v_current_variant = v_current_variant;
                EXECUTE stmt USING @v_current_variant;
                DEALLOCATE PREPARE stmt;
            ELSE
                INSERT INTO _VariantAttributes (va_id, attr_type)
                SELECT va.id, a.type 
                  FROM variant_attribute va
                  JOIN attribute a ON a.id = va.attribute_id
                 WHERE va.variant_id = v_current_variant;
            END IF;

            -- 3C) Process each variant attribute.
            SET done = FALSE;
            OPEN va_cursor;
            read_loop: LOOP
                FETCH va_cursor INTO cur_va_id, cur_attr_type;
                IF done THEN LEAVE read_loop; END IF;

                SELECT id 
                  INTO v_variantAttrVariantSpanId
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
                    SET v_existing_evav_id = NULL;
                    SET v_existing_span_id = NULL;
                END IF;

                IF p_regenerate_entity_state_id IS NOT NULL AND v_existing_evav_id IS NOT NULL THEN
                    SELECT COUNT(*) 
                      INTO v_lock_count 
                      FROM evav_lock
                     WHERE locked_evav_id = v_existing_evav_id;
                    IF v_lock_count > 0 THEN
                        SET v_used_span_id = v_existing_span_id;
                    ELSE
                        IF cur_attr_type = 'discrete' THEN
                            CALL roll_discrete_varattr(cur_va_id, v_variantAttrVariantSpanId, 0, p_commitHash);
                            SELECT @span_id INTO v_new_span_id;
                            UPDATE entity_varattr_value
                               SET span_id = v_new_span_id
                             WHERE id = v_existing_evav_id;
                            SET v_used_span_id = v_new_span_id;
                        ELSE
                            CALL roll_continuous_varattr(cur_va_id, v_variantAttrVariantSpanId, 0, p_commitHash);
                            SELECT @span_id, @chosen_value INTO v_new_span_id, v_new_numeric;
                            UPDATE entity_varattr_value
                               SET span_id = v_new_span_id, numeric_value = v_new_numeric
                             WHERE id = v_existing_evav_id;
                            SET v_used_span_id = v_new_span_id;
                        END IF;
                    END IF;
                ELSE
                    IF cur_attr_type = 'discrete' THEN
                        CALL roll_discrete_varattr(cur_va_id, v_variantAttrVariantSpanId, 0, p_commitHash);
                        SELECT @span_id INTO v_new_span_id;
                        INSERT INTO entity_varattr_value (
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
                        SET v_used_span_id = v_new_span_id;
                    ELSE
                        CALL roll_continuous_varattr(cur_va_id, v_variantAttrVariantSpanId, 0, p_commitHash);
                        SELECT @span_id, @chosen_value INTO v_new_span_id, v_new_numeric;
                        INSERT INTO entity_varattr_value (
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
                        SET v_used_span_id = v_new_span_id;
                    END IF;
                END IF;

                -- 3D) If the chosen span activates a sub–variant, enqueue it.
                IF v_use_commit THEN
                    SET @tbl_vas = CONCAT('variant_attr_span AS OF ''', p_commitHash, '''');
                    SET @sql = CONCAT(
                        'SELECT variant_id FROM ', @tbl_vas,
                        ' WHERE variant_attribute_id = ? AND id = ? LIMIT 1'
                    );
                    PREPARE stmt FROM @sql;
                    SET @cur_va_id = cur_va_id;
                    SET @v_used_span_id = v_used_span_id;
                    EXECUTE stmt USING @cur_va_id, @v_used_span_id INTO v_sub_variant_id;
                    DEALLOCATE PREPARE stmt;
                ELSE
                    SELECT variant_id 
                      INTO v_sub_variant_id
                      FROM variant_attr_span
                     WHERE variant_attribute_id = cur_va_id
                       AND id = v_used_span_id
                     LIMIT 1;
                END IF;
                IF v_sub_variant_id IS NOT NULL AND v_sub_variant_id <> v_current_variant THEN
                    INSERT IGNORE INTO _VariantQueue (variant_id)
                    VALUES (v_sub_variant_id);
                END IF;
            END LOOP;
            CLOSE va_cursor;
        END WHILE;

        DROP TEMPORARY TABLE IF EXISTS _VariantAttributes;
        DROP TEMPORARY TABLE IF EXISTS _VariantQueue;

        SELECT v_entity_state_id AS new_entity_state_id;
    END generate_entity_state_proc;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE reroll_entity_varattr_value(
    IN p_entityVarAttrValueId INT UNSIGNED,
    IN p_excludeCurrent BOOLEAN,
    IN p_commitHash VARCHAR(64)
)
BEGIN
    -- Local variables
    DECLARE v_variantAttributeId INT UNSIGNED;
    DECLARE v_currentSpanId      INT UNSIGNED DEFAULT 0;
    DECLARE v_attributeType      ENUM('discrete','continuous');
    DECLARE v_variantAttrVariantSpanId INT UNSIGNED;
    DECLARE v_excludeSpanId      INT UNSIGNED;
    
    -- Build dynamic table names for AS OF queries if a commit hash is provided.
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
    
    -- 1) Look up the variant_attribute_id and current span.
    SET @sql = CONCAT(
         'SELECT variant_attribute_id, IFNULL(span_id, 0) ',
         'FROM ', v_entity_table, ' ',
         'WHERE id = ?'
    );
    PREPARE stmt FROM @sql;
    SET @p_id = p_entityVarAttrValueId;
    EXECUTE stmt USING @p_id INTO v_variantAttributeId, v_currentSpanId;
    DEALLOCATE PREPARE stmt;
    
    -- 2) Get the attribute type from variant_attribute joined to attribute.
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
    
    -- 3) Look up the candidate variant_attr_span id.
    SET @sql = CONCAT(
         'SELECT variant_attr_span_id ',
         'FROM ', v_vavspan_table, ' ',
         'WHERE variant_attribute_id = ? LIMIT 1'
    );
    PREPARE stmt FROM @sql;
    SET @p_va2 = v_variantAttributeId;
    EXECUTE stmt USING @p_va2 INTO v_variantAttrVariantSpanId;
    DEALLOCATE PREPARE stmt;
    
    -- 4) Exclude the current span if requested.
    SET v_excludeSpanId = IF(p_excludeCurrent, v_currentSpanId, 0);
    
    -- 5) Call the proper roll procedure and update the record.
    IF v_attributeType = 'discrete' THEN
        CALL roll_discrete_varattr(
             v_variantAttributeId,
             v_variantAttrVariantSpanId,
             v_excludeSpanId,
             p_commitHash
        );
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
        UPDATE entity_varattr_value
          SET span_id = @span_id,
              numeric_value = @chosen_value
         WHERE id = p_entityVarAttrValueId;
    ELSE
        SIGNAL SQLSTATE '45000'
           SET MESSAGE_TEXT = 'Unknown attribute type';
    END IF;
    
    -- 6) Return the updated record.
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
    DECLARE v_attr_id INT UNSIGNED;
    DECLARE v_total_weight INT;
    DECLARE v_pinned_weight INT;
    DECLARE v_old_weight INT;
    DECLARE v_old_fraction DOUBLE;
    DECLARE v_pinned_fraction DOUBLE;
    DECLARE v_factor DOUBLE;
    DECLARE v_new_weight DOUBLE;
    DECLARE v_new_sum INT;
    DECLARE v_diff INT;
    
    -- Get attribute and current weight for the target span
    SELECT attribute_id, weight 
      INTO v_attr_id, v_old_weight
      FROM span
     WHERE id = in_span_id
       AND type = 'discrete';
    
    -- Aggregate total and pinned weights for discrete spans of the attribute
    SELECT 
      COALESCE(SUM(weight), 0),
      COALESCE(SUM(IF(is_percentage_pinned = 1, weight, 0)), 0)
      INTO v_total_weight, v_pinned_weight
      FROM span
     WHERE attribute_id = v_attr_id
       AND type = 'discrete';
    
    IF v_total_weight = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Total weight is 0 or no discrete spans exist.';
    END IF;
    
    SET v_old_fraction = v_old_weight / v_total_weight;
    SET v_pinned_fraction = v_pinned_weight / v_total_weight;
    
    IF (in_new_fraction + v_pinned_fraction) > 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'New fraction exceeds available unpinned portion.';
    END IF;
    
    -- If the target is the sole unpinned span, its fraction must equal 1 - pinned fraction
    IF ABS((1 - v_pinned_fraction) - v_old_fraction) < 1e-12 THEN
        IF ABS(in_new_fraction - (1 - v_pinned_fraction)) > 1e-12 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Only one unpinned span; new fraction must equal 1-pinned fraction.';
        END IF;
    ELSE
        -- Scale other unpinned spans proportionally
        SET v_factor = ((1 - v_pinned_fraction) - in_new_fraction)
                     / ((1 - v_pinned_fraction) - v_old_fraction);
        
        UPDATE span
           SET weight = ROUND(weight * v_factor)
         WHERE attribute_id = v_attr_id
           AND type = 'discrete'
           AND is_percentage_pinned = 0
           AND id <> in_span_id;
        
        -- Update the target span
        SET v_new_weight = in_new_fraction * v_total_weight;
        UPDATE span
           SET weight = ROUND(v_new_weight)
         WHERE id = in_span_id;
    END IF;
    
    -- Correct any rounding drift so the total weight remains constant
    SELECT SUM(weight)
      INTO v_new_sum
      FROM span
     WHERE attribute_id = v_attr_id
       AND type = 'discrete';
    
    SET v_diff = v_total_weight - v_new_sum;
    
    IF v_diff != 0 THEN
        UPDATE span
           SET weight = weight + v_diff
         WHERE id = in_span_id;
    END IF;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_variant_attribute(
    IN p_variant_id INT UNSIGNED,
    IN p_attribute_id INT UNSIGNED,
    IN p_name VARCHAR(255),
    IN p_position INT
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_position INT DEFAULT p_position;

    -- Count the number of variant_attributes currently in this variant.
    SELECT COUNT(*) INTO v_count 
      FROM variant_attribute 
     WHERE variant_id = p_variant_id;

    -- Enforce a minimum position of 0.
    IF v_position < 0 THEN 
        SET v_position = 0;
    END IF;
    
    -- If the position is greater than the current count, append at the end.
    IF v_position > v_count THEN
        SET v_position = v_count;
    END IF;

    -- Shift any existing variant_attributes at or after the new position upward by one.
    UPDATE variant_attribute
       SET causation_index = causation_index + 1
     WHERE variant_id = p_variant_id
       AND causation_index >= v_position;

    -- Insert the new variant_attribute with the proper (zero-indexed) causation_index.
    INSERT INTO variant_attribute (attribute_id, name, causation_index, variant_id)
    VALUES (p_attribute_id, p_name, v_position, p_variant_id);

    -- Return the new variant_attribute id.
    SELECT LAST_INSERT_ID() AS new_variant_attribute_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE remove_variant_attribute(
    IN p_variant_attribute_id INT UNSIGNED
)
BEGIN
    DECLARE v_variant_id INT UNSIGNED;
    DECLARE v_position INT;

    -- Retrieve the variant and the current index of the attribute to be removed.
    SELECT variant_id, causation_index 
      INTO v_variant_id, v_position
      FROM variant_attribute
     WHERE id = p_variant_attribute_id
     LIMIT 1;

    -- Delete the specified variant_attribute.
    DELETE FROM variant_attribute
     WHERE id = p_variant_attribute_id;

    -- Decrement the causation_index for all attributes that followed the removed one.
    UPDATE variant_attribute
       SET causation_index = causation_index - 1
     WHERE variant_id = v_variant_id
       AND causation_index > v_position;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE move_variant_attribute(
    IN p_variant_attribute_id INT UNSIGNED,
    IN p_new_position INT
)
BEGIN
    DECLARE v_variant_id INT UNSIGNED;
    DECLARE v_old_position INT;
    DECLARE v_count INT;

    -- Get the variant id and the current (zero-indexed) causation_index of the attribute.
    SELECT variant_id, causation_index 
      INTO v_variant_id, v_old_position
      FROM variant_attribute
     WHERE id = p_variant_attribute_id
     LIMIT 1;

    -- Determine the total number of attributes for this variant.
    SELECT COUNT(*) INTO v_count 
      FROM variant_attribute 
     WHERE variant_id = v_variant_id;

    -- For an attribute already in the list, valid positions are 0 to v_count-1.
    IF p_new_position < 0 THEN 
        SET p_new_position = 0;
    ELSEIF p_new_position > v_count - 1 THEN 
        SET p_new_position = v_count - 1;
    END IF;

    proc_move: BEGIN
        -- If the new position is the same as the current, no move is needed.
        IF p_new_position = v_old_position THEN
            LEAVE proc_move;
        END IF;

        IF p_new_position < v_old_position THEN
            -- Moving upward: increment the index for all attributes between the new and old positions.
            UPDATE variant_attribute
               SET causation_index = causation_index + 1
             WHERE variant_id = v_variant_id
               AND causation_index >= p_new_position
               AND causation_index < v_old_position;
        ELSE
            -- Moving downward: decrement the index for all attributes between the old and new positions.
            UPDATE variant_attribute
               SET causation_index = causation_index - 1
             WHERE variant_id = v_variant_id
               AND causation_index <= p_new_position
               AND causation_index > v_old_position;
        END IF;

        -- Set the moved attribute’s causation_index to the new position.
        UPDATE variant_attribute
           SET causation_index = p_new_position
         WHERE id = p_variant_attribute_id;
    END proc_move;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_discrete_span(
    IN p_attribute_id INT UNSIGNED,
    IN p_label VARCHAR(255)
)
BEGIN
  DECLARE v_total_weight INT;
  DECLARE v_unpinned_weight INT;
  DECLARE v_count_unpinned INT;
  DECLARE v_min_unpinned_weight INT;
  DECLARE v_scale_factor DOUBLE;
  DECLARE v_new_span_weight INT;
  DECLARE v_new_total INT;
  DECLARE v_diff INT;

  -- Get the overall total weight of discrete spans for the attribute.
  SELECT COALESCE(SUM(weight), 0)
    INTO v_total_weight
  FROM span
  WHERE attribute_id = p_attribute_id
    AND type = 'discrete';

  IF v_total_weight = 0 THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No discrete spans exist for attribute.';
  END IF;

  -- Get the sum and count for unpinned discrete spans.
  SELECT COALESCE(SUM(weight), 0), COUNT(*)
    INTO v_unpinned_weight, v_count_unpinned
  FROM span
  WHERE attribute_id = p_attribute_id
    AND type = 'discrete'
    AND is_percentage_pinned = 0;

  IF v_count_unpinned = 0 THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No unpinned discrete spans available for adjustment.';
  END IF;

  -- Find the minimum weight among unpinned spans.
  SELECT MIN(weight)
    INTO v_min_unpinned_weight
  FROM span
  WHERE attribute_id = p_attribute_id
    AND type = 'discrete'
    AND is_percentage_pinned = 0;

  -- The new span gets the minimum weight.
  SET v_new_span_weight = v_min_unpinned_weight;
  SET v_scale_factor = (v_unpinned_weight - v_new_span_weight) / v_unpinned_weight;

  -- Scale down all existing unpinned spans.
  UPDATE span
    SET weight = ROUND(weight * v_scale_factor)
  WHERE attribute_id = p_attribute_id
    AND type = 'discrete'
    AND is_percentage_pinned = 0;

  -- Insert the new span.
  INSERT INTO span(attribute_id, label, type, is_percentage_pinned, weight)
       VALUES(p_attribute_id, p_label, 'discrete', 0, v_new_span_weight);

  -- Adjust for any rounding drift.
  SELECT SUM(weight)
    INTO v_new_total
  FROM span
  WHERE attribute_id = p_attribute_id
    AND type = 'discrete';

  SET v_diff = v_total_weight - v_new_total;

  UPDATE span
    SET weight = weight + v_diff
  WHERE attribute_id = p_attribute_id
    AND type = 'discrete'
    AND label = p_label
    ORDER BY id DESC
    LIMIT 1;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE remove_discrete_span(
    IN p_span_id INT UNSIGNED
)
BEGIN
  DECLARE v_attribute_id INT UNSIGNED;
  DECLARE v_type ENUM('discrete','continuous');
  DECLARE v_is_pinned BOOLEAN;
  DECLARE v_total_weight INT;
  DECLARE v_unpinned_weight INT;
  DECLARE v_count_unpinned INT;
  DECLARE v_removed_weight INT;
  DECLARE v_scale_factor DOUBLE;
  DECLARE v_new_total INT;
  DECLARE v_diff INT;

  -- Look up the span to remove.
  SELECT attribute_id, type, is_percentage_pinned, weight
    INTO v_attribute_id, v_type, v_is_pinned, v_removed_weight
  FROM span
  WHERE id = p_span_id;

  IF v_type <> 'discrete' THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Span is not discrete.';
  END IF;
  IF v_is_pinned THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot remove a pinned span.';
  END IF;

  -- Get the overall discrete weight and unpinned total/count.
  SELECT COALESCE(SUM(weight), 0)
    INTO v_total_weight
  FROM span
  WHERE attribute_id = v_attribute_id
    AND type = 'discrete';

  SELECT COALESCE(SUM(weight), 0), COUNT(*)
    INTO v_unpinned_weight, v_count_unpinned
  FROM span
  WHERE attribute_id = v_attribute_id
    AND type = 'discrete'
    AND is_percentage_pinned = 0;

  IF v_count_unpinned <= 1 THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot remove the only unpinned span.';
  END IF;

  -- Remove the indicated span.
  DELETE FROM span WHERE id = p_span_id;

  -- Scale up the remaining unpinned spans.
  SET v_scale_factor = v_unpinned_weight / (v_unpinned_weight - v_removed_weight);
  UPDATE span
    SET weight = ROUND(weight * v_scale_factor)
  WHERE attribute_id = v_attribute_id
    AND type = 'discrete'
    AND is_percentage_pinned = 0;

  -- Adjust for rounding drift.
  SELECT SUM(weight)
    INTO v_new_total
  FROM span
  WHERE attribute_id = v_attribute_id
    AND type = 'discrete';

  SET v_diff = v_total_weight - v_new_total;
  UPDATE span
    SET weight = weight + v_diff
  WHERE attribute_id = v_attribute_id
    AND type = 'discrete'
    AND is_percentage_pinned = 0
    ORDER BY id ASC
    LIMIT 1;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_continuous_span(
    IN p_attribute_id INT UNSIGNED,
    IN p_label VARCHAR(255),
    IN p_new_min DOUBLE,
    IN p_new_max DOUBLE
)
BEGIN
    DECLARE v_attr_min, v_attr_max DOUBLE;
    DECLARE v_count INT;
    DECLARE v_first_id, v_last_id INT;
    DECLARE v_first_min, v_first_max DOUBLE;
    DECLARE v_last_min, v_last_max DOUBLE;
    
    -- Get attribute’s overall range (only continuous allowed)
    SELECT min_value, max_value
      INTO v_attr_min, v_attr_max
      FROM attribute
     WHERE id = p_attribute_id
       AND type = 'continuous'
     LIMIT 1;
    
    IF v_attr_min IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Attribute not found or not continuous';
    END IF;
    
    -- Validate requested span
    IF p_new_min < v_attr_min OR p_new_max > v_attr_max OR p_new_min >= p_new_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid span range';
    END IF;
    
    -- If no continuous spans exist, insert one covering the full range
    SELECT COUNT(*) INTO v_count
      FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'continuous';
    
    IF v_count = 0 THEN
        INSERT INTO span(attribute_id, label, type, min_value, max_value)
        VALUES(p_attribute_id, p_label, 'continuous', v_attr_min, v_attr_max);
        SELECT 'Continuous span inserted covering full range' AS message;
        LEAVE proc_end;
    END IF;
    
    -- Adjust overlapping spans: find first overlapping span (ordered by min_value)
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
    
    -- Find last overlapping span (ordered by max_value)
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
    
    -- Remove any spans entirely covered by the new span
    DELETE FROM span
     WHERE attribute_id = p_attribute_id
       AND type = 'continuous'
       AND min_value >= p_new_min
       AND max_value <= p_new_max;
    
    -- Insert the new span
    INSERT INTO span(attribute_id, label, type, min_value, max_value)
    VALUES(p_attribute_id, p_label, 'continuous', p_new_min, p_new_max);
    
proc_end: 
    SELECT 'Continuous span added successfully' AS message;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE remove_continuous_span(
    IN p_span_id INT UNSIGNED
)
BEGIN
    DECLARE v_attribute_id INT;
    DECLARE v_min, v_max DOUBLE;
    DECLARE v_count INT;
    DECLARE v_left_id INT DEFAULT NULL;
    DECLARE v_right_id INT DEFAULT NULL;
    
    -- Retrieve target span’s details (only continuous spans)
    SELECT attribute_id, min_value, max_value
      INTO v_attribute_id, v_min, v_max
      FROM span
     WHERE id = p_span_id
       AND type = 'continuous'
     LIMIT 1;
    
    IF v_attribute_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Span not found or not continuous';
    END IF;
    
    -- Ensure more than one continuous span exists
    SELECT COUNT(*) INTO v_count
      FROM span
     WHERE attribute_id = v_attribute_id
       AND type = 'continuous';
    
    IF v_count <= 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot remove the only continuous span';
    END IF;
    
    -- Look for an adjacent span on the left
    SELECT id INTO v_left_id
      FROM span
     WHERE attribute_id = v_attribute_id
       AND type = 'continuous'
       AND max_value = v_min
     LIMIT 1;
    
    -- Look for an adjacent span on the right
    SELECT id INTO v_right_id
      FROM span
     WHERE attribute_id = v_attribute_id
       AND type = 'continuous'
       AND min_value = v_max
     LIMIT 1;
    
    -- Expand an adjacent span to cover the gap (prefer left)
    IF v_left_id IS NOT NULL THEN
        UPDATE span SET max_value = v_max WHERE id = v_left_id;
    ELSEIF v_right_id IS NOT NULL THEN
        UPDATE span SET min_value = v_min WHERE id = v_right_id;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No adjacent span found to merge with';
    END IF;
    
    -- Delete the target span
    DELETE FROM span WHERE id = p_span_id;
    
    SELECT 'Continuous span removed and adjacent span merged successfully' AS message;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE set_variant_span(
    IN p_variant_attribute_id INT UNSIGNED,
    IN p_span_id              INT UNSIGNED,
    IN p_sub_variant_id       INT UNSIGNED
)
BEGIN
    DECLARE v_parent_variant_id INT UNSIGNED;
    DECLARE v_attr_id           INT UNSIGNED;
    DECLARE v_span_attr_id      INT UNSIGNED;
    DECLARE v_vas_id            INT UNSIGNED;

    -- (1) Get parent variant and attribute from variant_attribute.
    SELECT variant_id, attribute_id
      INTO v_parent_variant_id, v_attr_id
      FROM variant_attribute
     WHERE id = p_variant_attribute_id;
    IF v_parent_variant_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Variant attribute not found.';
    END IF;

    -- (2) Verify that the span exists and belongs to the same attribute.
    SELECT attribute_id
      INTO v_span_attr_id
      FROM span
     WHERE id = p_span_id;
    IF v_span_attr_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Span not found.';
    END IF;
    IF v_span_attr_id <> v_attr_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Span does not belong to the attribute for this variant attribute.';
    END IF;

    -- (3) Upsert the variant_attr_span record.
    INSERT INTO variant_attr_span (span_id, variant_attribute_id, variant_id)
      VALUES (p_span_id, p_variant_attribute_id, p_sub_variant_id)
      ON DUPLICATE KEY UPDATE 
          variant_id = VALUES(variant_id),
          id = LAST_INSERT_ID(id);
    SET v_vas_id = LAST_INSERT_ID();

    -- (4) Upsert the corresponding record in vavspan_attr.
    INSERT INTO vavspan_attr (variant_attribute_id, variant_attr_span_id)
      VALUES (p_variant_attribute_id, v_vas_id)
      ON DUPLICATE KEY UPDATE
          variant_attr_span_id = VALUES(variant_attr_span_id);
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE unset_variant_span(
    IN p_variant_attribute_id INT UNSIGNED,
    IN p_span_id              INT UNSIGNED
)
BEGIN
    DECLARE v_parent_variant_id INT UNSIGNED;
    DECLARE v_vas_id            INT UNSIGNED;

    -- (1) Get the parent variant from variant_attribute.
    SELECT variant_id
      INTO v_parent_variant_id
      FROM variant_attribute
     WHERE id = p_variant_attribute_id;
    IF v_parent_variant_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Variant attribute not found.';
    END IF;

    -- (2) Locate the variant_attr_span record.
    SELECT id
      INTO v_vas_id
      FROM variant_attr_span
     WHERE variant_attribute_id = p_variant_attribute_id
       AND span_id = p_span_id;
    IF v_vas_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'No variant_attr_span record found for the given parameters.';
    END IF;

    -- (3) Reset the variant_attr_span record back to the parent variant.
    UPDATE variant_attr_span
       SET variant_id = v_parent_variant_id
     WHERE id = v_vas_id;

    -- (4) Remove the corresponding record from vavspan_attr.
    DELETE FROM vavspan_attr
     WHERE variant_attribute_id = p_variant_attribute_id
       AND variant_attr_span_id = v_vas_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_continuous_variation(
    IN p_activating_span_id         INT UNSIGNED,
    IN p_to_modify_vavspan_attr_id  INT UNSIGNED,
    IN p_activating_vavspan_attr_id INT UNSIGNED,
    IN p_delta_normal              DOUBLE,
    IN p_delta_percent_normal      DOUBLE,
    IN p_delta_percent_skewed      DOUBLE
)
BEGIN
    DECLARE v_variation_id INT UNSIGNED;

    -- Create the variation record (is_inactive defaults to 0)
    INSERT INTO variation (
        activating_span_id,
        to_modify_vavspan_attr_id,
        activating_vavspan_attr_id
    )
    VALUES (
        p_activating_span_id,
        p_to_modify_vavspan_attr_id,
        p_activating_vavspan_attr_id
    );
    SET v_variation_id = LAST_INSERT_ID();

    -- Insert the continuous attribute details
    INSERT INTO variation_continuous_attr (
        variation_id,
        delta_normal,
        delta_percent_normal,
        delta_percent_skewed
    )
    VALUES (
        v_variation_id,
        p_delta_normal,
        p_delta_percent_normal,
        p_delta_percent_skewed
    );

    -- Return the new variation id
    SELECT v_variation_id AS variation_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE remove_continuous_variation(
    IN p_variation_id INT UNSIGNED
)
BEGIN
    -- Deleting variation cascades
    DELETE FROM variation WHERE id = p_variation_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_delta_weight_variation(
    IN p_activating_span_id         INT UNSIGNED,
    IN p_to_modify_vavspan_attr_id  INT UNSIGNED,
    IN p_activating_vavspan_attr_id INT UNSIGNED,
    IN p_target_span_id             INT UNSIGNED,
    IN p_delta_weight             DOUBLE
)
BEGIN
    DECLARE v_variation_id INT UNSIGNED;

    -- Create the variation record.
    INSERT INTO variation (
        activating_span_id,
        to_modify_vavspan_attr_id,
        activating_vavspan_attr_id
    )
    VALUES (
        p_activating_span_id,
        p_to_modify_vavspan_attr_id,
        p_activating_vavspan_attr_id
    );
    SET v_variation_id = LAST_INSERT_ID();

    -- Insert the delta weight detail.
    INSERT INTO variation_delta_weight (
        span_id,
        variation_id,
        delta_weight
    )
    VALUES (
        p_target_span_id,
        v_variation_id,
        p_delta_weight
    );

    SELECT v_variation_id AS variation_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE remove_delta_weight_variation(
    IN p_variation_id INT UNSIGNED
)
BEGIN
    -- Deleting variation cascades
    DELETE FROM variation WHERE id = p_variation_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_deactivated_span_variation(
    IN p_activating_span_id         INT UNSIGNED,
    IN p_to_modify_vavspan_attr_id  INT UNSIGNED,
    IN p_activating_vavspan_attr_id INT UNSIGNED,
    IN p_deactivated_span_id        INT UNSIGNED
)
BEGIN
    DECLARE v_variation_id INT UNSIGNED;

    -- Create the variation record; set is_inactive = 1.
    INSERT INTO variation (
        activating_span_id,
        to_modify_vavspan_attr_id,
        activating_vavspan_attr_id,
        is_inactive
    )
    VALUES (
        p_activating_span_id,
        p_to_modify_vavspan_attr_id,
        p_activating_vavspan_attr_id,
        1
    );
    SET v_variation_id = LAST_INSERT_ID();

    -- Record the deactivated span.
    INSERT INTO variation_inactive_span (
        span_id,
        variation_id
    )
    VALUES (
        p_deactivated_span_id,
        v_variation_id
    );

    SELECT v_variation_id AS variation_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE remove_deactivated_span_variation(
    IN p_variation_id INT UNSIGNED
)
BEGIN
    -- Deleting variation cascades
    DELETE FROM variation WHERE id = p_variation_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_activated_span_variation(
    IN p_activating_span_id         INT UNSIGNED,
    IN p_to_modify_vavspan_attr_id  INT UNSIGNED,
    IN p_activating_vavspan_attr_id INT UNSIGNED,
    IN p_attribute_id               INT UNSIGNED,
    IN p_label                      VARCHAR(255),
    IN p_weight                     INT
)
BEGIN
    DECLARE v_new_span_id INT UNSIGNED;
    DECLARE v_variation_id INT UNSIGNED;

    -- (1) Create a new span record.
    INSERT INTO span (
        attribute_id,
        label,
        type,
        is_percentage_pinned,
        weight,
        max_value,
        min_value
    )
    VALUES (
        p_attribute_id,
        p_label,
        'discrete',
        FALSE,
        p_weight,
        NULL,
        NULL
    );
    SET v_new_span_id = LAST_INSERT_ID();

    -- (2) Create the variation record.
    INSERT INTO variation (
        activating_span_id,
        to_modify_vavspan_attr_id,
        activating_vavspan_attr_id
    )
    VALUES (
        p_activating_span_id,
        p_to_modify_vavspan_attr_id,
        p_activating_vavspan_attr_id
    );
    SET v_variation_id = LAST_INSERT_ID();

    -- (3) Link the new span to the variation.
    INSERT INTO variation_activated_span (
        span_id,
        variation_id
    )
    VALUES (
        v_new_span_id,
        v_variation_id
    );

    SELECT v_variation_id AS variation_id, v_new_span_id AS activated_span_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE remove_activated_span_variation(
    IN p_variation_id INT UNSIGNED
)
BEGIN
    DECLARE v_activated_span_id INT UNSIGNED;

    -- Retrieve the activated span id associated with this variation.
    SELECT span_id
      INTO v_activated_span_id
      FROM variation_activated_span
     WHERE variation_id = p_variation_id
     LIMIT 1;

    -- Delete the variation record (cascades to variation_activated_span).
    DELETE FROM variation
     WHERE id = p_variation_id;

    -- Remove the activated span from the span table.
    DELETE FROM span
     WHERE id = v_activated_span_id;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE lock_entity_varattr_value(IN p_evav_id INT UNSIGNED)
BEGIN
  WITH RECURSIVE dependency_chain (evav_id, entity_state_id, variant_attribute_id, span_id, locking_evav_id) AS (
    -- Base: start with the given EVAV.
    SELECT
      evav.id,
      evav.entity_state_id,
      evav.variant_attribute_id,
      evav.span_id,
      NULL
    FROM entity_varattr_value evav
    WHERE evav.id = p_evav_id

    UNION ALL

    -- Recursive: for each EVAV, join its dependency record to find its parent EVAV.
    SELECT
      parent_evav.id,
      parent_evav.entity_state_id,
      parent_evav.variant_attribute_id,
      parent_evav.span_id,
      child.evav_id
    FROM dependency_chain AS child
      JOIN vavspan_attr AS vva
        ON vva.variant_attribute_id = child.variant_attribute_id
      JOIN variant_attr_span AS vas
        ON vas.id = vva.variant_attr_span_id
      JOIN entity_varattr_value AS parent_evav
        ON parent_evav.entity_state_id    = child.entity_state_id
       AND parent_evav.variant_attribute_id = vas.variant_attribute_id
       AND parent_evav.span_id            = vas.span_id
  )
  INSERT INTO evav_lock (locked_evav_id, locking_evav_id)
  SELECT d.evav_id, d.locking_evav_id
  FROM (
    SELECT DISTINCT evav_id, locking_evav_id
    FROM dependency_chain
  ) AS d
  LEFT JOIN evav_lock AS l
    ON l.locked_evav_id = d.evav_id
   AND (
         (d.locking_evav_id IS NULL AND l.locking_evav_id IS NULL)
      OR (d.locking_evav_id IS NOT NULL AND l.locking_evav_id = d.locking_evav_id)
       )
  WHERE l.id IS NULL;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE unlock_entity_varattr_value(IN p_evav_id INT UNSIGNED)
BEGIN
    DECLARE v_direct_lock INT DEFAULT 0;
    DECLARE v_dep_lock INT DEFAULT 0;

    -- Ensure the EVAV is directly locked.
    SELECT COUNT(*) INTO v_direct_lock
      FROM evav_lock
     WHERE locked_evav_id = p_evav_id
       AND locking_evav_id IS NULL;
    IF v_direct_lock = 0 THEN
      SIGNAL SQLSTATE '45000'
         SET MESSAGE_TEXT = 'EVAV is not directly locked; cannot unlock.';
    END IF;

    -- Delete dependency lock rows where this EVAV is the “locker”.
    DELETE FROM evav_lock
     WHERE locking_evav_id = p_evav_id;

    -- Finally, delete the direct lock row.
    DELETE FROM evav_lock
     WHERE locked_evav_id = p_evav_id
       AND locking_evav_id IS NULL;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE list_commits()
BEGIN
    -- Query Dolt’s log view; adjust columns if needed.
    SELECT commit_hash, message, date
    FROM dolt_log
    ORDER BY date DESC;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE create_commit(
    IN in_commit_message VARCHAR(255)
)
BEGIN
    CALL DOLT_COMMIT(in_commit_message);
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE list_entities_of_commit(
    IN in_commit_hash CHAR(32)
)
BEGIN
    SELECT *
    FROM entity
    WHERE commit_hash = in_commit_hash;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_variant(
    IN in_variant_name VARCHAR(255)
)
BEGIN
    INSERT INTO variant (name)
    VALUES (in_variant_name);
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE modify_variant(
    IN in_variant_id INT,
    IN in_variant_name VARCHAR(255)
)
BEGIN
    UPDATE variant
    SET name = in_variant_name
    WHERE id = in_variant_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE delete_variant(
    IN in_variant_id INT
)
BEGIN
    DELETE FROM variant
    WHERE id = in_variant_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE list_variants()
BEGIN
    SELECT *
    FROM variant
    ORDER BY name;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_attribute(
    IN in_name VARCHAR(255),
    IN in_type ENUM('discrete','continuous'),
    IN in_decimals INT,
    IN in_has_labels BOOLEAN,
    IN in_has_value BOOLEAN,
    IN in_max_value DOUBLE,
    IN in_min_value DOUBLE,
    IN in_normal_value DOUBLE,
    IN in_percent_normal DOUBLE,
    IN in_percent_skewed DOUBLE,
    IN in_units VARCHAR(255)
)
BEGIN
    INSERT INTO attribute
      (name, type, decimals, has_labels, has_value, max_value, min_value,
       normal_value, percent_normal, percent_skewed, units)
    VALUES
      (in_name, in_type, in_decimals, in_has_labels, in_has_value, in_max_value,
       in_min_value, in_normal_value, in_percent_normal, in_percent_skewed, in_units);
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE modify_attribute(
    IN in_id INT,
    IN in_name VARCHAR(255),
    IN in_type ENUM('discrete','continuous'),
    IN in_decimals INT,
    IN in_has_labels BOOLEAN,
    IN in_has_value BOOLEAN,
    IN in_max_value DOUBLE,
    IN in_min_value DOUBLE,
    IN in_normal_value DOUBLE,
    IN in_percent_normal DOUBLE,
    IN in_percent_skewed DOUBLE,
    IN in_units VARCHAR(255)
)
BEGIN
    UPDATE attribute
    SET name = in_name,
        type = in_type,
        decimals = in_decimals,
        has_labels = in_has_labels,
        has_value = in_has_value,
        max_value = in_max_value,
        min_value = in_min_value,
        normal_value = in_normal_value,
        percent_normal = in_percent_normal,
        percent_skewed = in_percent_skewed,
        units = in_units
    WHERE id = in_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE delete_attribute(
    IN in_id INT
)
BEGIN
    DELETE FROM attribute
    WHERE id = in_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE list_attributes()
BEGIN
    SELECT *
    FROM attribute
    ORDER BY name;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE add_entity(
    IN in_variant_id INT,
    IN in_commit_hash CHAR(32)
)
BEGIN
    INSERT INTO entity (variant_id, commit_hash)
    VALUES (in_variant_id, in_commit_hash);
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE modify_entity(
    IN in_entity_id INT,
    IN in_variant_id INT,
    IN in_commit_hash CHAR(32)
)
BEGIN
    UPDATE entity
    SET variant_id = in_variant_id,
        commit_hash = in_commit_hash
    WHERE id = in_entity_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE delete_entity(
    IN in_entity_id INT
)
BEGIN
    DELETE FROM entity
    WHERE id = in_entity_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE list_entities()
BEGIN
    SELECT DISTINCT v.*
    FROM variant v
    JOIN entity e ON v.id = e.variant_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE resolve_entity_state(
  IN in_entity_state_id INT
)
BEGIN
  SELECT 
    e.id AS entity_id,
    v.name AS variant_name,
    e.commit_hash,
    es.id AS entity_state_id,
    es.time,
    evav.id AS evav_id,
    evav.numeric_value,
    va.id AS variant_attribute_id,
    va.name AS variant_attribute_name,
    va.causation_index,
    a.id AS attribute_id,
    a.name AS attribute_name,
    a.type AS attribute_type,
    s.id AS span_id,
    s.label AS span_label,
    s.type AS span_type,
    l1.locking_evav_id AS locked_by_evav_id,
    l2.locked_evav_id AS is_locking_evav_id
  FROM entity_state es
    JOIN entity e ON es.entity_id = e.id
    JOIN variant v ON e.variant_id = v.id
    LEFT JOIN entity_varattr_value evav ON es.id = evav.entity_state_id
    LEFT JOIN variant_attribute va ON evav.variant_attribute_id = va.id
    LEFT JOIN attribute a ON va.attribute_id = a.id
    LEFT JOIN span s ON evav.span_id = s.id
    LEFT JOIN evav_lock l1 ON l1.locked_evav_id = evav.id
    LEFT JOIN evav_lock l2 ON l2.locking_evav_id = evav.id
  WHERE es.id = in_entity_state_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE delete_entity_state(
  IN in_entity_state_id INT
)
BEGIN
  DELETE FROM entity_state
  WHERE id = in_entity_state_id;
END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE list_entity_states(
  IN in_entity_id INT
)
BEGIN
  SELECT es.id, es.time
  FROM entity_state es
  WHERE es.entity_id = in_entity_id
  ORDER BY es.time;
END $$
DELIMITER ;












