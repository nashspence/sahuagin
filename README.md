# Sahuagin Database

This repository contains the PostgreSQL schema and stored procedures for the Sahuagin project. All SQL sources live in the `sql/` directory and can be loaded into any PostgreSQL server. The entry point `00_init.sql` includes definitions from the `schema`, `functions` and `procedures` folders.

## Starting the database

Install PostgreSQL and optionally `pgcli`. Create and load the database with:

```bash
sudo -u postgres createdb sahuagin
sudo -u postgres psql -d sahuagin -f sql/00_init.sql
```

To explore the schema interactively:

```bash
sudo -u postgres pgcli sahuagin
```

## Example usage

After loading `sql/00_init.sql`, the script `sql/examples/test_generation.sql` creates two minimal mechanisms, generates states and a grouping, and runs both initial generation and regeneration of states.

Run it with:

```bash
sudo -u postgres psql -d sahuagin -f sql/examples/test_generation.sql
```

This demonstrates the stored procedures `create_mechanism`, `generate_state` and `generate_grouping`. Each mechanism stores a small Python module with a required `generate()` function. The module may also define `validate(state)`, which `validate_state` executes on a JSON representation of an entity state.

The example also defines a `combo_mech` that composes `number_mech` and `string_mech`:

```sql
-- def validate(state):
--     num_ok = delegate('number_mech', state['number'])
--     str_ok = delegate('string_mech', state['string'])
--     return num_ok and str_ok and use_input('number/num') == 42
--
-- SELECT validate_state('combo_mech',
--   '{"number":{"num":42},"string":{"msg":"hello"}}');
```

## Development

Tests require PostgreSQL to be installed locally and can be run with:

```bash
pytest
```

## License

This project is available under the [MIT](LICENSE) license.
