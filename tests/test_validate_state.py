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


@pytest.fixture(scope='module', autouse=True)
def db():
    subprocess.run(['sudo', '-u', 'postgres', 'createdb', DB_NAME], check=True)
    subprocess.run(['sudo', '-u', 'postgres', 'psql', '-d', DB_NAME, '-f', str(SQL_INIT)], check=True)
    yield
    subprocess.run(['sudo', '-u', 'postgres', 'dropdb', DB_NAME], check=True)


def test_validate_state():
    number_module = textwrap.dedent(
        """
        def generate():
            add_output('num', 42)
            if False:
                yield

        def validate(state):
            return use_input('num') == 42
        """
    )

    string_module = textwrap.dedent(
        """
        def generate():
            add_output('msg', 'hello')
            if False:
                yield

        def validate(state):
            return use_input('msg') == 'hello'
        """
    )

    combo_module = textwrap.dedent(
        """
        def generate():
            yield from activate('number_mech', 'num')
            yield from activate('string_mech', 'str')

        def validate(state):
            num_ok = delegate('number_mech', state.get('number'))
            str_ok = delegate('string_mech', state.get('string'))
            return (
                num_ok and str_ok and
                use_input('number/num') == 42 and
                use_input('string/msg') == 'hello'
            )
        """
    )

    run_psql(['-c', f"CALL create_mechanism('number_mech', $PYTHON$\n{number_module}$PYTHON$);"])
    run_psql(['-c', f"CALL create_mechanism('string_mech', $PYTHON$\n{string_module}$PYTHON$);"])
    run_psql(['-c', f"CALL create_mechanism('combo_mech', $PYTHON$\n{combo_module}$PYTHON$);"])

    valid_state = '{"number":{"num":42},"string":{"msg":"hello"}}'
    result = run_psql(['-At', '-c', f"SELECT validate_state('combo_mech', '{valid_state}');"])
    assert result.stdout.strip() == 't'

    invalid_state_num = '{"number":{"num":41},"string":{"msg":"hello"}}'
    result = run_psql(['-At', '-c', f"SELECT validate_state('combo_mech', '{invalid_state_num}');"])
    assert result.stdout.strip() == 'f'

    invalid_state_str = '{"number":{"num":42},"string":{"msg":"bye"}}'
    result = run_psql(['-At', '-c', f"SELECT validate_state('combo_mech', '{invalid_state_str}');"])
    assert result.stdout.strip() == 'f'
