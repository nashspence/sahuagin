import subprocess
import pathlib
import os

DB_NAME = os.environ.get('DB_NAME', 'sahuagin_test')
ROOT = pathlib.Path(__file__).resolve().parents[1]
SQL_INIT = ROOT / 'sql' / '00_init.sql'

def run_psql(args, *, expect_success=True):
    cmd = ['sudo', '-u', 'postgres', 'psql', '-v', 'ON_ERROR_STOP=1', '-d', DB_NAME] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    if expect_success and result.returncode != 0:
        raise RuntimeError(f"psql failed: {result.stderr}")
    return result
