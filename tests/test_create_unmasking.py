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


def test_create_unmasking_removes_state():
    # Define simple mechanisms used in the test.
    worker_old = textwrap.dedent(
        """
        def generate():
            add_output('msg', 'old')
            if False:
                yield
        """
    )
    worker_new = textwrap.dedent(
        """
        def generate():
            add_output('msg', 'new')
            if False:
                yield
        """
    )
    root_module = textwrap.dedent(
        """
        def generate():
            yield from activate('worker_old', 'child')
        """
    )

    # Create mechanisms
    run_psql(['-c', f"CALL create_mechanism('worker_old', $PYTHON$\n{worker_old}$PYTHON$);"])
    run_psql(['-c', f"CALL create_mechanism('worker_new', $PYTHON$\n{worker_new}$PYTHON$);"])
    run_psql(['-c', f"CALL create_mechanism('root_mech', $PYTHON$\n{root_module}$PYTHON$);"])

    # Create an entity using the root mechanism and generate its state.
    run_psql(['-c', "INSERT INTO entity (name, mechanism) SELECT 'e1', id FROM mechanism WHERE name = 'root_mech';"])
    run_psql(['-c', "CALL generate_state('e1', 0);"])

    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM state;'])
    assert result.stdout.strip() == '1'

    # Create unmasking for the child activation and ensure states are removed.
    run_psql(['-c', "CALL create_unmasking('root_mech', 'child', 'worker_new');"])

    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM unmasking;'])
    assert result.stdout.strip() == '1'

    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM state;'])
    assert result.stdout.strip() == '0'
