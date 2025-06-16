import textwrap
from .helpers import ROOT, run_psql


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
