import textwrap
from .helpers import ROOT, run_psql


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
