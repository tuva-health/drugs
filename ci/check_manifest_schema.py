"""Guard the package schema contract without connecting to a warehouse."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("manifest", type=Path)
parser.add_argument("--schema", required=True)
args = parser.parse_args()
manifest = json.loads(args.manifest.read_text())
nodes = [
    node for node in manifest["nodes"].values()
    if node["package_name"] == "drugs"
    and node["resource_type"] in {"model", "seed"}
]
if not nodes or not any(node["resource_type"] == "seed" for node in nodes):
    raise SystemExit("Expected enabled Drugs models and seeds in the integration manifest")
wrong = {node["unique_id"]: node["schema"] for node in nodes if node["schema"] != args.schema}
if wrong:
    raise SystemExit(f"Drugs schema prefix was not applied: {wrong}")
print(f"Verified {len(nodes)} Drugs models/seeds use {args.schema}")
