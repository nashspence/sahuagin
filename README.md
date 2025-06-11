# Sahuagin Database

This repository centers around the Jupyter notebook `Create the Sahuagin Database.ipynb`. The notebook contains the latest schema and logic for building a generative attribute database in PostgreSQL.

## Starting the development environment

A small Docker Compose configuration starts Jupyter and PostgreSQL together:

```bash
docker-compose up -d
```

Jupyter will be available on port `8888` and PostgreSQL on `5432`. The access token for Jupyter is written to `server.txt` and also set via the `JUPYTER_TOKEN` variable in `docker-compose.yml`.

## Using the notebook

Open the `Create the Sahuagin Database.ipynb` notebook from the Jupyter interface and run the cells. The notebook installs PostgreSQL locally inside the container, creates the database and loads all required procedures.

The previous notebooks remain under `notebooks/` for reference.
