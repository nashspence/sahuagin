import subprocess
import pytest
from . import helpers

@pytest.fixture(scope='module', autouse=True)
def db():
    subprocess.run(['sudo', '-u', 'postgres', 'createdb', helpers.DB_NAME], check=True)
    subprocess.run(['sudo', '-u', 'postgres', 'psql', '-d', helpers.DB_NAME, '-f', str(helpers.SQL_INIT)], check=True)
    yield
    subprocess.run(['sudo', '-u', 'postgres', 'dropdb', helpers.DB_NAME], check=True)
