DROP TABLE IF EXISTS mechanism CASCADE;
CREATE TABLE mechanism (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL UNIQUE,
  module text NOT NULL
);

-- Activation table now links mechanisms.
-- "from_mechanism" continues through an activation (by name) to the "to_mechanism",
-- and the activation is defined in the context of a "root_mechanism".
-- The unique constraint ensures that (from_mechanism, root_mechanism, name) is unique.
DROP TABLE IF EXISTS activation CASCADE;
CREATE TABLE activation (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL,
  from_mechanism integer NOT NULL,
  root_mechanism integer NOT NULL,
  to_mechanism integer NOT NULL,
  CONSTRAINT uq_activation UNIQUE (from_mechanism, root_mechanism, name),
  CONSTRAINT fk_activation_from FOREIGN KEY (from_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE,
  CONSTRAINT fk_activation_root FOREIGN KEY (root_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE,
  CONSTRAINT fk_activation_to FOREIGN KEY (to_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE
);

-- New table "unmasking"
-- This table provides a reference between a root mechanism, an activation,
-- and a mechanism that is being unmasked (unmasked_to_mechanism).
DROP TABLE IF EXISTS unmasking CASCADE;
CREATE TABLE unmasking (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  root_mechanism integer NOT NULL,
  activation integer NOT NULL,
  unmasked_to_mechanism integer NOT NULL,
  CONSTRAINT fk_unmasking_root FOREIGN KEY (root_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE,
  CONSTRAINT fk_unmasking_activation FOREIGN KEY (activation)
    REFERENCES activation(id) ON DELETE CASCADE,
  CONSTRAINT fk_unmasking_unmasked FOREIGN KEY (unmasked_to_mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE
);

-- The entity table now associates an entity with a mechanism.
DROP TABLE IF EXISTS entity CASCADE;
CREATE TABLE entity (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL,
  mechanism integer NOT NULL,
  CONSTRAINT fk_entity_mechanism FOREIGN KEY (mechanism)
    REFERENCES mechanism(id) ON DELETE CASCADE
);

-- Snapshot (state) of an entity at a moment in time.
DROP TABLE IF EXISTS state CASCADE;
CREATE TABLE state (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity integer NOT NULL,
  time double precision NOT NULL,
  CONSTRAINT uq_state UNIQUE (entity, time),
  CONSTRAINT fk_state_entity FOREIGN KEY (entity)
    REFERENCES entity(id) ON DELETE CASCADE
);

-- Locked relationships between state and activation for partial re-generation.
DROP TABLE IF EXISTS locked_activation CASCADE;
CREATE TABLE locked_activation (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  state integer NOT NULL,
  activation integer NOT NULL,
  CONSTRAINT fk_locked_activation_state FOREIGN KEY (state)
    REFERENCES state(id) ON DELETE CASCADE,
  CONSTRAINT fk_locked_activation_activation FOREIGN KEY (activation)
    REFERENCES activation(id) ON DELETE CASCADE
);

-- Enum indicating the type of value stored.
DROP TYPE IF EXISTS value_type CASCADE;
CREATE TYPE value_type AS ENUM ('string', 'number');

-- Abstract value representing mechanism states.
DROP TABLE IF EXISTS value CASCADE;
CREATE TABLE value (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  state integer NOT NULL,
  activation integer NOT NULL,
  name citext NOT NULL,
  type value_type NOT NULL,
  CONSTRAINT fk_value_state FOREIGN KEY (state)
    REFERENCES state(id) ON DELETE CASCADE,
  CONSTRAINT fk_value_activation FOREIGN KEY (activation)
    REFERENCES activation(id) ON DELETE CASCADE
);

-- Numeric value.
DROP TABLE IF EXISTS number_value CASCADE;
CREATE TABLE number_value (
  value integer PRIMARY KEY,
  serialized double precision NOT NULL,
  CONSTRAINT fk_number_value FOREIGN KEY (value)
    REFERENCES value(id) ON DELETE CASCADE
);

-- String value.
DROP TABLE IF EXISTS string_value CASCADE;
CREATE TABLE string_value (
  value integer PRIMARY KEY,
  serialized text NOT NULL,
  CONSTRAINT fk_string_value FOREIGN KEY (value)
    REFERENCES value(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS value_antecedent CASCADE;
CREATE TABLE value_antecedent (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    value integer NOT NULL,
    child integer NOT NULL,
    antecedent integer NOT NULL,
    CONSTRAINT fk_value_antecedent_value FOREIGN KEY (value)
        REFERENCES value(id) ON DELETE CASCADE,
    CONSTRAINT fk_value_antecedent_child FOREIGN KEY (child)
        REFERENCES activation(id) ON DELETE CASCADE,
    CONSTRAINT fk_value_antecedent_antecedent FOREIGN KEY (antecedent)
        REFERENCES activation(id) ON DELETE CASCADE,
    UNIQUE (value, child, antecedent)
);

DROP TABLE IF EXISTS locked_dependency CASCADE;
CREATE TABLE locked_dependency (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state integer NOT NULL,
    value integer NOT NULL,
    activation integer NOT NULL,
    CONSTRAINT fk_locked_dependency_state FOREIGN KEY (state)
        REFERENCES state(id) ON DELETE CASCADE,
    CONSTRAINT fk_locked_dependency_value FOREIGN KEY (value)
        REFERENCES value(id) ON DELETE CASCADE,
    CONSTRAINT fk_locked_dependency_activation FOREIGN KEY (activation)
        REFERENCES activation(id) ON DELETE CASCADE,
    UNIQUE (state, value, activation)
);

-- grouping of entity states.
DROP TABLE IF EXISTS grouping CASCADE;
CREATE TABLE grouping (
  id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name citext NOT NULL UNIQUE
);

-- Entity observed in a grouping.
DROP TABLE IF EXISTS grouping_entity CASCADE;
CREATE TABLE grouping_entity (
  entity integer PRIMARY KEY,
  grouping integer NOT NULL,
  CONSTRAINT fk_grouping_entity_entity FOREIGN KEY (entity)
    REFERENCES entity(id) ON DELETE CASCADE,
  CONSTRAINT fk_grouping_entity_grouping FOREIGN KEY (grouping)
    REFERENCES grouping(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS debug_log CASCADE;
CREATE TABLE debug_log (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_time timestamp DEFAULT CURRENT_TIMESTAMP,
    procedure_name varchar(255),
    log_message text
);
