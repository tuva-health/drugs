"""Build an Open ingredient bridge from NLM's public-domain Prescribable subset.

Download a dated RxNorm_full_prescribe_MMDDYYYY.zip from NLM, then:
python scripts/build_rxnorm_ingredient_map.py --zip release.zip --release-date YYYY-MM-DD --output map.parquet
Load the Parquet into terminology.rxnorm_drug_ingredient (or override its source vars).
No patient data or CodeRx Enterprise content is consumed or distributed.
"""
import argparse,collections,hashlib,json,zipfile
from pathlib import Path
import pyarrow as pa
import pyarrow.parquet as pq

ALLOWED_TYPES={'IN','PIN','MIN','SCD','SBD','SCDC','SBDC','SCDF','SBDF','GPCK','BPCK'}
RELATIONS={'has_ingredient','has_precise_ingredient','has_ingredients','has_part',
           'form_of','consists_of','contains','tradename_of','quantified_form_of'}

def build_mapping(archive,release_date):
    concepts={};graph=collections.defaultdict(set)
    with zipfile.ZipFile(archive) as z:
        def records(suffix):
            names=[n for n in z.namelist() if n.endswith('/'+suffix) or n==suffix]
            if len(names)!=1:raise ValueError('Expected exactly one '+suffix)
            for raw in z.open(names[0]):yield raw.decode('utf-8').rstrip('\r\n').split('|')
        for a in records('RXNCONSO.RRF'):
            if a[11]=='RXNORM' and a[16]=='N' and a[12] in ALLOWED_TYPES:
                concepts[a[0]]=(a[12],a[14])
        for a in records('RXNREL.RRF'):
            # NLM: RXCUI2 bears RELA to RXCUI1, not the reverse.
            if a[10]=='RXNORM' and a[14] in ('','N') and a[7] in RELATIONS and a[4] in concepts and a[0] in concepts:
                graph[a[4]].add(a[0])
    rows=[]
    for drug_id in sorted(concepts):
        visited=set();pending=[drug_id];ingredients=set()
        while pending:
            code=pending.pop()
            if code in visited:continue
            visited.add(code)
            if concepts[code][0]=='IN':ingredients.add(code)
            else:pending.extend(graph[code]-visited)
        for ingredient in sorted(ingredients):
            rows.append({'drug_id':drug_id,'ingredient_id':ingredient,
                         'ingredient_name':concepts[ingredient][1],
                         'source_release_date':release_date,'mapping_source':'NLM RxNorm Current Prescribable Content'})
    if not rows:raise ValueError('No ingredient relationships found')
    return rows

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--zip',required=True,type=Path);p.add_argument('--release-date',required=True)
    p.add_argument('--output',required=True,type=Path);a=p.parse_args()
    rows=build_mapping(a.zip,a.release_date);a.output.parent.mkdir(parents=True,exist_ok=True)
    pq.write_table(pa.Table.from_pylist(rows),a.output)
    meta={'source':'NLM RxNorm Current Prescribable Content','release_date':a.release_date,
          'archive_sha256':hashlib.sha256(a.zip.read_bytes()).hexdigest(),
          'rows':len(rows),'mapped_concepts':len({r['drug_id'] for r in rows}),
          'relationships':sorted(RELATIONS),'license':'public domain; no UMLS license required'}
    a.output.with_suffix('.json').write_text(json.dumps(meta,indent=2));print(json.dumps(meta))

if __name__=='__main__':main()
