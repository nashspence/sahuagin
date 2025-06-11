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
