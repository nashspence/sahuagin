
-- Helper mechanism used by number_mech to actually emit the output
CALL create_mechanism('number_worker', $PYTHON$
def generate():
    add_output('num', 42)
    if False:
        yield
$PYTHON$);

-- Root numeric mechanism activates the worker
CALL create_mechanism('number_mech', $PYTHON$
import uuid

def generate():
    unique_name = 'num_' + uuid.uuid4().hex[:8]
    yield from activate('number_worker', unique_name)

def validate(state):
    return use_input('num') == 42
$PYTHON$);

-- Helper mechanism used by string_mech to emit the greeting
CALL create_mechanism('string_worker', $PYTHON$
def generate():
    add_output('msg', 'hello')
    if False:
        yield
$PYTHON$);

-- Root string mechanism activates the worker
CALL create_mechanism('string_mech', $PYTHON$
import uuid

def generate():
    unique_name = 'msg_' + uuid.uuid4().hex[:8]
    yield from activate('string_worker', unique_name)

def validate(state):
    return use_input('msg') == 'hello'
$PYTHON$);

-- Create an entity that uses the numeric mechanism
INSERT INTO entity (mechanism, name)
SELECT id, 'num_entity' FROM mechanism WHERE name = 'number_mech';

-- Initial state generation for the entity
CALL generate_state('num_entity', 0);

-- Regenerate the same state by clearing previous records
TRUNCATE state, activation, value, number_value, string_value,
        value_antecedent, locked_activation, locked_dependency
        RESTART IDENTITY CASCADE;
CALL generate_state('num_entity', 0);

-- Create a grouping of two string mechanism entities
CALL generate_grouping('string_mech', 'demo_group', 'demo_%s', 2);

-- View grouping results at time 0 (optional)
-- SELECT * FROM get_grouping_at_time('demo_group', 0);

-- Regenerate each grouped entity
CALL generate_state('demo_1', 0);
CALL generate_state('demo_2', 0);

-- Composed mechanism that activates number_mech and string_mech
CALL create_mechanism('combo_mech', $PYTHON$
import uuid

def generate():
    yield from activate('number_mech', 'num_' + uuid.uuid4().hex[:8])
    yield from activate('string_mech', 'str_' + uuid.uuid4().hex[:8])

def validate(state):
    num_ok = delegate('number_mech', state.get('number'))
    str_ok = delegate('string_mech', state.get('string'))
    return (
        num_ok and str_ok and
        use_input('number/num') == 42 and
        use_input('string/msg') == 'hello'
    )
$PYTHON$);

-- Example validation call
-- SELECT validate_state('combo_mech', '{"number":{"num":42},"string":{"msg":"hello"}}');
