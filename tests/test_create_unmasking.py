import textwrap
from .helpers import ROOT, run_psql


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
