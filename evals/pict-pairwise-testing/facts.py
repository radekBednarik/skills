#!/usr/bin/env python3
"""Collect mechanically checkable facts about one eval run.

Usage: facts.py <outputs-dir> <path-to-pict>

Prints JSON. Graders use it as evidence, so that claims such as "the table
came from PICT" are verified by rerunning PICT instead of being judged by eye.
"""
import glob
import json
import os
import re
import subprocess
import sys


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def model_values(text):
    """Return {parameter: [values]} from the parameter section of a model."""
    params = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("{"):
            continue
        if re.match(r"(?i)^(if\b|\[|not\b|\()", line):
            break
        if ":" not in line:
            continue
        name, values = line.split(":", 1)
        cleaned = []
        for value in values.split(","):
            first_alias = value.split("|")[0].strip()
            first_alias = re.sub(r"\s*\(\d+\)$", "", first_alias)
            if first_alias:
                cleaned.append(first_alias)
        params[name.strip()] = cleaned
    return params


def main():
    out_dir, pict = sys.argv[1], sys.argv[2]
    facts = {"files": sorted(os.listdir(out_dir))}
    models = sorted(glob.glob(os.path.join(out_dir, "*.pict")))
    tables = sorted(glob.glob(os.path.join(out_dir, "*.tsv")))
    facts["model_files"] = [os.path.basename(m) for m in models]
    facts["tsv_files"] = [os.path.basename(t) for t in tables]
    facts["other_model_like_files"] = [
        f for f in facts["files"]
        if f.endswith((".txt", ".model", ".csv")) and f not in ("commands.md",)
    ]

    facts["models"] = []
    for model in models:
        entry = {"model": os.path.basename(model)}
        run = subprocess.run([pict, model], capture_output=True, text=True)
        entry["pict_exit"] = run.returncode
        entry["pict_stderr"] = run.stderr.strip()
        rows = [r for r in run.stdout.splitlines() if r.strip()]
        entry["pict_rows"] = max(len(rows) - 1, 0)
        params = model_values(read(model))
        entry["parameters"] = params
        exhaustive = 1
        for values in params.values():
            exhaustive *= max(len(values), 1)
        entry["exhaustive_count_unconstrained"] = exhaustive

        stem = os.path.splitext(model)[0]
        twin = stem + ".tsv"
        candidates = [twin] if os.path.exists(twin) else tables
        entry["matching_tsv"] = None
        for table in candidates:
            if read(table).strip().splitlines() == run.stdout.strip().splitlines():
                entry["matching_tsv"] = os.path.basename(table)
                break
        entry["tsv_equals_deterministic_pict_rerun"] = entry["matching_tsv"] is not None
        facts["models"].append(entry)

    facts["tables"] = []
    for table in tables:
        lines = [l for l in read(table).splitlines() if l.strip()]
        header = lines[0].split("\t") if lines else []
        rows = [l.split("\t") for l in lines[1:]]
        seen = {h: set() for h in header}
        for row in rows:
            for name, cell in zip(header, row):
                seen[name].add(cell.strip().lstrip("~"))
        facts["tables"].append({
            "tsv": os.path.basename(table),
            "header": header,
            "row_count": len(rows),
            "rows_with_tilde": sum(1 for r in rows if any(c.startswith("~") for c in r)),
            "max_tilde_values_in_one_row": max(
                (sum(1 for c in r if c.startswith("~")) for r in rows), default=0),
            "values_seen": {k: sorted(v) for k, v in seen.items()},
            "rows": rows,
        })

    # Values declared in a model but absent from its table.
    for entry in facts["models"]:
        table = next((t for t in facts["tables"] if t["tsv"] == entry["matching_tsv"]), None)
        if table is None and facts["tables"]:
            table = facts["tables"][0]
        missing = {}
        if table:
            for name, values in entry["parameters"].items():
                seen = {v.lower() for v in table["values_seen"].get(name, [])}
                gone = [v for v in values if v.lstrip("~").lower() not in seen]
                if gone:
                    missing[name] = gone
        entry["declared_values_missing_from_table"] = missing

    print(json.dumps(facts, indent=2))


if __name__ == "__main__":
    main()
