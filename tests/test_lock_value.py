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


def test_lock_value_dependency_closure():
    sql_setup = textwrap.dedent(
        """
        INSERT INTO mechanism(name, module) VALUES
          ('root_mech', ''),
          ('worker1', ''),
          ('worker2', '');

        INSERT INTO entity(name, mechanism)
        SELECT 'e1', id FROM mechanism WHERE name='root_mech';

        INSERT INTO state(entity, time)
        SELECT id, 0 FROM entity WHERE name='e1';

        INSERT INTO activation(name, from_mechanism, root_mechanism, to_mechanism)
        SELECT 'w1', r.id, r.id, w1.id
        FROM mechanism r, mechanism w1
        WHERE r.name='root_mech' AND w1.name='worker1';

        INSERT INTO activation(name, from_mechanism, root_mechanism, to_mechanism)
        SELECT 'w2', w1.id, r.id, w2.id
        FROM mechanism r, mechanism w1, mechanism w2
        WHERE r.name='root_mech' AND w1.name='worker1' AND w2.name='worker2';

        INSERT INTO value(state, activation, name, type)
        SELECT s.id, a.id, 'base', 'number'
        FROM state s, activation a
        WHERE s.entity=(SELECT id FROM entity WHERE name='e1')
          AND s.time=0 AND a.name='w1';

        INSERT INTO number_value(value, serialized)
        SELECT v.id, 1
        FROM value v JOIN activation a ON v.activation=a.id
        WHERE v.name='base' AND a.name='w1';

        INSERT INTO value(state, activation, name, type)
        SELECT s.id, a.id, 'derived', 'number'
        FROM state s, activation a
        WHERE s.entity=(SELECT id FROM entity WHERE name='e1')
          AND s.time=0 AND a.name='w2';

        INSERT INTO number_value(value, serialized)
        SELECT v.id, 2
        FROM value v JOIN activation a ON v.activation=a.id
        WHERE v.name='derived' AND a.name='w2';

        INSERT INTO value_antecedent(value, child, antecedent)
        SELECT v_base.id, a_child.id, a_parent.id
        FROM value v_base, activation a_parent, activation a_child
        WHERE v_base.name='base' AND a_parent.name='w1'
          AND a_child.name='w2' AND v_base.activation = a_parent.id;
        """
    )
    setup_file = ROOT / 'tests' / 'setup_lock.sql'
    setup_file.write_text(sql_setup)
    try:
        run_psql(['-f', str(setup_file)])
        run_psql(['-c', "CALL lock_value('e1', 0, 'w1/w2', 'derived');"])
        result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM locked_dependency;'])
        assert result.stdout.strip() == '2'
        result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM locked_activation;'])
        assert result.stdout.strip() == '2'

        # Repeat call should not create duplicates
        run_psql(['-c', "CALL lock_value('e1', 0, 'w1/w2', 'derived');"])
        result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM locked_dependency;'])
        assert result.stdout.strip() == '2'
        result = run_psql(['-At', '-c', 'SELECT COUNT(*) FROM locked_activation;'])
        assert result.stdout.strip() == '2'
    finally:
        setup_file.unlink()
