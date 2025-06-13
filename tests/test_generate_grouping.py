import subprocess
import pathlib
import textwrap
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


def test_generate_grouping_creates_entities_and_state():
    module = textwrap.dedent(
        """
        def generate():
            if False:
                yield
        """
    )

    run_psql(['-c', f"CALL create_mechanism('basic_mech', $PYTHON$\n{module}$PYTHON$);"])
    run_psql(['-c', "CALL generate_grouping('basic_mech', 'group1', 'ent_%s', 3);"])

    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM entity;'])
    assert result.stdout.strip() == '3'

    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM state WHERE time=0;'])
    assert result.stdout.strip() == '3'

    result = run_psql(['-At', '-c', "SELECT COUNT(*) FROM grouping WHERE name='group1';"])
    assert result.stdout.strip() == '1'

    result = run_psql([
        '-At',
        '-c',
        "SELECT COUNT(*) FROM grouping_entity ge JOIN grouping g ON ge.grouping=g.id WHERE g.name='group1';",
    ])
    assert result.stdout.strip() == '3'
