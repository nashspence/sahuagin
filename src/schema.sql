DROP DATABASE sahuagin;
CREATE DATABASE sahuagin;
USE sahuagin;

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
    CHECK (max_value IS NULL OR min_value IS NULL
        OR max_value >= min_value),
    CHECK ((type = 'discrete' AND decimals IS NULL
        AND has_labels IS NULL
        AND has_value IS NULL
        AND max_value IS NULL
        AND min_value IS NULL
        AND normal_value IS NULL
        AND percent_normal IS NULL
        AND percent_skewed IS NULL
        AND units IS NULL)
        OR (type = 'continuous'
        AND decimals IS NOT NULL
        AND has_labels IS NOT NULL
        AND has_value IS NOT NULL
        AND max_value IS NOT NULL
        AND min_value IS NOT NULL
        AND normal_value IS NOT NULL
        AND percent_normal IS NOT NULL
        AND percent_skewed IS NOT NULL))
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
    CONSTRAINT `fk_spans_attr` FOREIGN KEY (`attribute_id`)
        REFERENCES `attribute` (`id`)
        ON DELETE CASCADE,
    CHECK (max_value IS NULL OR min_value IS NULL
        OR max_value >= min_value),
    CHECK ((type = 'discrete'
        AND is_percentage_pinned IS NOT NULL
        AND weight IS NOT NULL
        AND max_value IS NULL
        AND min_value IS NULL)
        OR (type = 'continuous'
        AND is_percentage_pinned IS NULL
        AND weight IS NULL
        AND max_value IS NOT NULL
        AND min_value IS NOT NULL))
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
    CONSTRAINT `fk_variant_attr_attr` FOREIGN KEY (`attribute_id`)
        REFERENCES `attribute` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_variant_attr_variant` FOREIGN KEY (`variant_id`)
        REFERENCES `variant` (`id`)
        ON DELETE CASCADE
);
CREATE TABLE `variant_attr_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    `variant_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_varattr_span_span` FOREIGN KEY (`span_id`)
        REFERENCES `span` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_varattr_span_varattr` FOREIGN KEY (`variant_attribute_id`)
        REFERENCES `variant_attribute` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_varattr_span_variant` FOREIGN KEY (`variant_id`)
        REFERENCES `variant` (`id`)
        ON DELETE CASCADE
);-- short for variant_attribute_variant_span
CREATE TABLE `vavspan_attr` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    `variant_attr_span_id` INT UNSIGNED,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_vavspan_attr_va` FOREIGN KEY (`variant_attribute_id`)
        REFERENCES `variant_attribute` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_vavspan_attr_vas` FOREIGN KEY (`variant_attr_span_id`)
        REFERENCES `variant_attr_span` (`id`)
        ON DELETE CASCADE
);-- short for variant_attribute_variant_span_variant_attribute
CREATE TABLE `variation` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `activating_span_id` INT UNSIGNED NOT NULL,
    `to_modify_vavspan_attr_id` INT UNSIGNED NOT NULL,
    `activating_vavspan_attr_id` INT UNSIGNED NOT NULL,
    `is_inactive` BOOLEAN NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_variation_span` FOREIGN KEY (`activating_span_id`)
        REFERENCES `span` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_variation_vavspan_to_modify` FOREIGN KEY (`to_modify_vavspan_attr_id`)
        REFERENCES `vavspan_attr` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_variation_vavspan_activating` FOREIGN KEY (`activating_vavspan_attr_id`)
        REFERENCES `vavspan_attr` (`id`)
        ON DELETE CASCADE
);
CREATE TABLE `variation_continuous_attr` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variation_id` INT UNSIGNED NOT NULL,
    `delta_normal` DOUBLE NOT NULL,
    `delta_percent_normal` DOUBLE NOT NULL,
    `delta_percent_skewed` DOUBLE NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_continuous_attr_var` FOREIGN KEY (`variation_id`)
        REFERENCES `variation` (`id`)
        ON DELETE CASCADE
);-- short for variation_on_continuous_attribute
CREATE TABLE `variation_activated_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_activated_span_span` FOREIGN KEY (`span_id`)
        REFERENCES `span` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_var_activated_span_var` FOREIGN KEY (`variation_id`)
        REFERENCES `variation` (`id`)
        ON DELETE CASCADE
);
CREATE TABLE `variation_delta_weight` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `delta_weight` DOUBLE NOT NULL,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_delta_weight_span` FOREIGN KEY (`span_id`)
        REFERENCES `span` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_var_delta_weight_var` FOREIGN KEY (`variation_id`)
        REFERENCES `variation` (`id`)
        ON DELETE CASCADE
);
CREATE TABLE `variation_inactive_span` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `span_id` INT UNSIGNED NOT NULL,
    `variation_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_var_inactive_span_span` FOREIGN KEY (`span_id`)
        REFERENCES `span` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_var_inactive_span_var` FOREIGN KEY (`variation_id`)
        REFERENCES `variation` (`id`)
        ON DELETE CASCADE
);
CREATE TABLE `entity` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `variant_id` INT UNSIGNED NOT NULL,
    `commit_hash` CHAR(32) NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_entity_variant` FOREIGN KEY (`variant_id`)
        REFERENCES `variant` (`id`)
        ON DELETE CASCADE
);
CREATE TABLE `entity_state` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `entity_id` INT UNSIGNED NOT NULL,
    `time` DOUBLE NOT NULL UNIQUE,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_entity` FOREIGN KEY (`entity_id`)
        REFERENCES `entity` (`id`)
        ON DELETE CASCADE
);
CREATE TABLE `entity_varattr_value` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `entity_state_id` INT UNSIGNED NOT NULL,
    `numeric_value` DOUBLE,
    `span_id` INT UNSIGNED,
    `variant_attribute_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_evav_entity_state` FOREIGN KEY (`entity_state_id`)
        REFERENCES `entity_state` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_evav_span` FOREIGN KEY (`span_id`)
        REFERENCES `span` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_evav_variant_attr` FOREIGN KEY (`variant_attribute_id`)
        REFERENCES `variant_attribute` (`id`)
        ON DELETE CASCADE
);-- short for entity_variant_attribute_value
CREATE TABLE `evav_lock` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `locked_evav_id` INT UNSIGNED NOT NULL,
    `locking_evav_id` INT UNSIGNED,
    PRIMARY KEY (`id`),
    CONSTRAINT `fk_evav_lock_locked_evav` FOREIGN KEY (`locked_evav_id`)
        REFERENCES `entity_varattr_value` (`id`)
        ON DELETE CASCADE,
    CONSTRAINT `fk_evav_lock_locking_evav` FOREIGN KEY (`locking_evav_id`)
        REFERENCES `entity_varattr_value` (`id`)
        ON DELETE CASCADE
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