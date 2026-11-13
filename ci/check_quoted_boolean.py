"""Prove invalid quoted booleans fail during parse, without warehouse access."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--enterprise", choices=["false", "true"], default="false")
args = parser.parse_args()
project = Path(__file__).resolve().parents[1] / "integration_tests"
variables = {
    "use_coderx_enterprise": args.enterprise == "true",
    "tuva_schema_prefix": "ci",
    "drugs_stockpile_early_refills": "false",
}
result = subprocess.run(
    [str(Path(sys.executable).with_name("dbt")), "parse", "--no-partial-parse",
     "--profiles-dir", "../ci", "--target-path", "target/negative-boolean",
     "--vars", json.dumps(variables)],
    cwd=project, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
)
message = "drugs_stockpile_early_refills must be a YAML boolean"
if result.returncode == 0 or message not in result.stdout:
    print(result.stdout)
    raise SystemExit("Expected a parse failure identifying the invalid stockpile boolean")
print("Verified quoted stockpile boolean is rejected during parse")
