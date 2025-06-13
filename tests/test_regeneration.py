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


def test_regeneration_skips_locked_activation():
    # Define mechanisms
    worker_emit = textwrap.dedent(
        """
        def generate():
            add_output('num', 1)
            if False:
                yield
        """
    )
    worker_use = textwrap.dedent(
        """
        def generate():
            val = int(use_input('../emit/num'))
            add_output('double', val * 2)
            if False:
                yield
        """
    )
    root_module = textwrap.dedent(
        """
        def generate():
            yield from activate('worker_emit', 'emit')
            yield from activate('worker_use', 'use')
        """
    )

    # Create mechanisms
    run_psql(['-c', f"CALL create_mechanism('worker_emit', $PYTHON$\n{worker_emit}$PYTHON$);"])
    run_psql(['-c', f"CALL create_mechanism('worker_use', $PYTHON$\n{worker_use}$PYTHON$);"])
    run_psql(['-c', f"CALL create_mechanism('root_mech', $PYTHON$\n{root_module}$PYTHON$);"])

    # Create entity and generate initial state
    run_psql(['-c', "INSERT INTO entity (mechanism, name) SELECT id, 'e1' FROM mechanism WHERE name = 'root_mech';"])
    run_psql(['-c', "CALL generate_state('e1', 0);"])

    # Verify activations were created
    result = run_psql([
        '-At',
        '-F', ',',
        '-c',
        'SELECT id, get_activation_full_path(id) FROM activation ORDER BY 2;'
    ])
    rows = [tuple(r.split(',')) for r in result.stdout.strip().splitlines()]
    assert rows == [(rows[0][0], 'emit'), (rows[1][0], 'use')]
    emit_id, use_id = rows[0][0], rows[1][0]

    # Verify values and dependency
    result = run_psql([
        '-At',
        '-F', ',',
        '-c',
        (
            'SELECT get_activation_full_path(v.activation), v.name,'
            ' COALESCE(nv.serialized::text, sv.serialized)'
            ' FROM value v'
            ' LEFT JOIN number_value nv ON nv.value=v.id'
            ' LEFT JOIN string_value sv ON sv.value=v.id'
            ' ORDER BY 1'
        )
    ])
    vals = [tuple(r.split(',')) for r in result.stdout.strip().splitlines()]
    assert ('emit', 'num', '1') in vals
    assert ('use', 'double', '2') in vals

    result = run_psql([
        '-At',
        '-F', ',',
        '-c',
        'SELECT get_activation_full_path(child), get_activation_full_path(antecedent) FROM value_antecedent'
    ])
    assert result.stdout.strip() == 'use,emit'

    # Lock the value from the first worker
    run_psql(['-c', "CALL lock_value('e1', 0, 'emit', 'num');"])

    # Regenerate state
    run_psql(['-c', "CALL generate_state('e1', 0);"])

    # Existing activations should be reused and values preserved
    result = run_psql([
        '-At',
        '-F', ',',
        '-c',
        'SELECT id, get_activation_full_path(id) FROM activation ORDER BY 2;'
    ])
    rows_after = [tuple(r.split(',')) for r in result.stdout.strip().splitlines()]
    assert rows_after == [(emit_id, 'emit'), (use_id, 'use')]

    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM value;'])
    assert result.stdout.strip() == '2'
    result = run_psql([
        '-At',
        '-F', ',',
        '-c',
        'SELECT get_activation_full_path(child), get_activation_full_path(antecedent) FROM value_antecedent'
    ])
    assert result.stdout.strip() == 'use,emit'
    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM locked_activation;'])
    assert result.stdout.strip() == '2'
    result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM locked_dependency;'])
    assert result.stdout.strip() == '2'
