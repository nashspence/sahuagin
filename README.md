# Sahuagin Database

This repository contains the PostgreSQL schema and stored procedures for the Sahuagin project. The definitions are located in `sql/schema.sql` and are loaded automatically when the database container starts.

## Starting the database

A minimal Docker Compose setup runs PostgreSQL and loads the schema:

```bash
docker-compose up -d
```

PostgreSQL will be available on port `5432` with the default credentials `postgres`/`postgres`.

## Schema

All tables, functions, and procedures are defined in `sql/schema.sql`. The original Jupyter notebooks are kept in `notebooks/` for historical reference.
