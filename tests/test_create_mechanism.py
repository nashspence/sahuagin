import subprocess
import pathlib
import textwrap
import os
import pytest

DB_NAME = 'sahuagin_test'
ROOT = pathlib.Path(__file__).resolve().parents[1]
SQL_INIT = ROOT / 'sql' / '00_init.sql'


def run_psql(args, *, expect_success=True):
    cmd = ['sudo', '-u', 'postgres', 'psql', '-v', 'ON_ERROR_STOP=1', '-d', DB_NAME] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    if expect_success and result.returncode != 0:
        raise RuntimeError(f"psql failed: {result.stderr}")
    return result


@pytest.fixture(scope="module", autouse=True)
def db():
    subprocess.run(['sudo', '-u', 'postgres', 'createdb', DB_NAME], check=True)
    subprocess.run(['sudo', '-u', 'postgres', 'psql', '-d', DB_NAME, '-f', str(SQL_INIT)], check=True)
    yield
    subprocess.run(['sudo', '-u', 'postgres', 'dropdb', DB_NAME], check=True)


def test_create_mechanism_unique_violation():
    module = textwrap.dedent(
        """\
        def generate():
            if False:
                yield
        """
    )
    sql_file = ROOT / 'tests' / 'create_mech.sql'
    sql_file.write_text(
        "CALL create_mechanism('test_mech', $PYTHON$\n" + module + "$PYTHON$);\n"
    )
    try:
        run_psql(['-f', str(sql_file)])
        result = run_psql(['-At', '-c', "SELECT COUNT(*) FROM mechanism WHERE name='test_mech';"])
        assert result.stdout.strip() == '1'

        result = run_psql(['-f', str(sql_file)], expect_success=False)
        assert result.returncode != 0
    finally:
        sql_file.unlink()
