import textwrap
from .helpers import ROOT, run_psql


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
