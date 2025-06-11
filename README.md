# Sahuagin Database

This repository contains SQL schemas and stored procedures for a generative attribute database. The project aims to implement an advanced generative supply chain management (SCM) system entirely in database logic. PostgreSQL is the primary target. Legacy MariaDB versions of the schema and procedures remain under `src/` for reference.

## Starting the development environment

A small Docker configuration is included to launch a Jupyter notebook image that also exposes a PostgreSQL server. Start the container with:

```bash
docker-compose up -d
```

The container exposes Jupyter on port `8888` and PostgreSQL on `5432`. The Jupyter token can be found in `server.txt` or in the environment variable `JUPYTER_TOKEN` defined in `docker-compose.yml`.

## Initializing the database

After the container is running, connect to PostgreSQL and execute the SQL scripts in `src/`:

```bash
# Load the schema
PGPASSWORD="test" psql -h localhost -p 5432 -U postgres -f src/schema.postgres.sql

# Load the stored procedures
PGPASSWORD="test" psql -h localhost -p 5432 -U postgres -f src/procedures.postgres.sql
```

Legacy MariaDB scripts (`schema.mariadb.sql` and `procedures.mariadb.sql`) are also available for backward compatibility.

## Advanced generative tasks

The `src/procedures.postgres.sql` script defines many stored procedures for
building a fully generative SCM system. Some highlights:

- `generate_entity_state` and `generate_entity_states_in_range` produce full sets
  of attribute values for an entity at a specific time or across a time range.
- `reroll_entity_varattr_value` allows targeted re-generation of a single
  attribute when only one value needs to change.
- `add_variant_attribute`, `remove_variant_attribute` and
  `move_variant_attribute` manage the ordered attributes that make up a
  variant template.
- `set_discrete_span_percentage`, `add_discrete_span` and related procedures
  adjust probability weights for discrete spans.
- Higher-level procedures such as `add_variant`, `modify_variant`,
  `add_entity` and `resolve_entity_state` help maintain entities and variants
  entirely inside PostgreSQL.

By chaining these procedures you can construct complex generative pipelines. For
example, variants describing inventory items can be rolled over time to produce
new states, or narrative elements can evolve as conditions change. Once the
database is initialized, all of this logic runs inside PostgreSQL with no external
code required.

## Tests

The `test/` directory contains example SQL tests and helper scripts:

- `basic_gen_test.sql` – exercises stored procedures by creating sample data.
- `reset.sh` – drops and recreates the database.
- `print_logs.sh` – prints debugging logs from the `debug_log` table.
- `test_1.ipynb` – a Jupyter notebook demonstrating a simple test workflow.

Once the container and database are set up you can run the shell scripts from the host machine, for example:

```bash
bash test/reset.sh
psql -h localhost -p 5432 -U postgres -d sahuagin -f test/basic_gen_test.sql
bash test/print_logs.sh
```

These commands assume the default password of `test` for the `postgres` user.
