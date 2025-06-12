# Sahuagin Database

This repository contains the PostgreSQL schema and stored procedures for the Sahuagin project. The SQL files live under `sql/` and can be loaded into any PostgreSQL server. The entry point `00_init.sql` includes the individual definitions from the `schema`, `functions`, and `procedures` folders.

## Starting the database

Install PostgreSQL and `pgcli` on your system. The database can then be created
and loaded with:

```bash
sudo -u postgres createdb sahuagin
sudo -u postgres psql -d sahuagin -f sql/00_init.sql
```

To explore the schema using `pgcli`:

```bash
sudo -u postgres pgcli sahuagin
```

## Schema

All tables, functions, and procedures are organized in separate files under `sql/`. The original Jupyter notebooks are kept in `notebooks/` for historical reference.

## Example usage

After loading `sql/00_init.sql`, the script `sql/examples/test_generation.sql`
creates two minimal mechanisms, generates states and a grouping, and runs both
initial generation and regeneration of states.

Run it with:

```bash
sudo -u postgres psql -d sahuagin -f sql/examples/test_generation.sql
```

This demonstrates the stored procedures `create_mechanism`, `generate_state`
and `generate_grouping` in action. Each mechanism stores a single Python module
with a required `generate()` function. The same module may optionally define
`validate(state)`, which the `validate_state` function executes on a JSON
representation of an entity state.

The example also defines a `combo_mech` which composes `number_mech` and
`string_mech`. Its validator illustrates delegating checks to child
mechanisms using the `delegate()` helper and reading nested values with
`use_input()`:

```sql
-- def validate(state):
--     num_ok = delegate('number_mech', state['number'])
--     str_ok = delegate('string_mech', state['string'])
--     return num_ok and str_ok and use_input('number/num') == 42
--
-- SELECT validate_state('combo_mech', '{"number":{"num":42},"string":{"msg":"hello"}}');
```

## Validation workflow

When creating a mechanism you supply a single Python module. It **must**
define `generate()` for state generation and **may** define `validate(state)`.
The module is stored in the `mechanism.module` column. `validate_state('<mechanism>', '<json>')` loads this module and exposes
`delegate()` and `use_input()` to it. Validators can call
`delegate(mechanism_name, state_fragment)` to invoke another mechanism's
validator and use `use_input(path)` to read values from the provided state
using `/`-separated paths.
No other modules (such as `plpy` or `json`) are available inside the
validator; use only these helpers when inspecting the input or delegating to
other mechanisms.

A short example:

```sql
CALL create_mechanism('number_mech',
$PYTHON$
import uuid

def generate():
    yield from activate('number_worker', 'num_' + uuid.uuid4().hex[:8])

def validate(state):
    return use_input('num') == 42
$PYTHON$);

SELECT validate_state('number_mech', '{"num":42}');
```

Calling `validate_state('number_mech', '{"num":42}')` will execute the
`validate` function defined in the module.
