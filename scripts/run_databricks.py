"""Run dbt using an existing Databricks CLI OAuth login, without writing a token."""
import argparse,json,os,subprocess,sys,tempfile
from pathlib import Path
import yaml
p=argparse.ArgumentParser()
p.add_argument('--cli-profile',required=True)
p.add_argument('--host',required=True)
p.add_argument('--warehouse',required=True)
p.add_argument('--catalog',required=True)
p.add_argument('--schema',default='drugs')
p.add_argument('--artifacts',required=True,type=Path)
p.add_argument('--vars-file',type=Path)
p.add_argument('command',nargs=argparse.REMAINDER)
a=p.parse_args()
if not a.command:p.error('Provide a dbt command, such as build.')
project=Path(__file__).resolve().parents[1]
r=subprocess.run(['databricks','auth','token',a.cli_profile,'-o','json'],capture_output=True,text=True,check=True)
env=os.environ.copy();env['DBT_ENV_SECRET_DATABRICKS_TOKEN']=json.loads(r.stdout)['access_token']
env['DBT_LOG_PATH']=str(a.artifacts.resolve()/'logs');env['DBT_TARGET_PATH']=str(a.artifacts.resolve()/'target')
profile={'drugs':{'target':'dev','outputs':{'dev':{'type':'databricks','host':a.host,'http_path':'/sql/1.0/warehouses/'+a.warehouse,'token':"{{ env_var('DBT_ENV_SECRET_DATABRICKS_TOKEN') }}",'catalog':a.catalog,'schema':a.schema,'threads':4}}}}
variables=yaml.safe_load(a.vars_file.read_text()) if a.vars_file else {}
with tempfile.TemporaryDirectory() as d:
 Path(d,'profiles.yml').write_text(yaml.safe_dump(profile))
 cmd=[str(Path(sys.executable).parent/'dbt'),*a.command,'--project-dir',str(project),'--profiles-dir',d,'--profile','drugs','--vars',json.dumps(variables)]
 raise SystemExit(subprocess.run(cmd,env=env).returncode)
