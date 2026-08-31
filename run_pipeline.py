#!/usr/bin/env python
"""Run the whole pipeline, raw exports -> data handed to the analysis repo.

    python run_pipeline.py              # everything
    python run_pipeline.py --from 4     # resume from step 4
    python run_pipeline.py --list       # show the steps and stop

Must be run from the repo root, in the project conda environment.
AI labels and model fits are committed as source and are never re-run.
"""
import argparse, glob, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.abspath(__file__))


def labeling(pass_dir):
    """Every loc*.ipynb in a labeling pass, in numeric order."""
    import re
    fs = glob.glob(os.path.join(ROOT, "scripts", "labeling", pass_dir, "loc*.ipynb"))
    return sorted(fs, key=lambda p: int(re.search(r"loc(\d+)", os.path.basename(p)).group(1)))


def steps():
    s = [
        ("1  preprocess raw exports",      ["scripts/1_preprocessing.ipynb"]),
        ("2  encoding fixes",              ["scripts/1.1_encoding_errors.ipynb"]),
        ("3  clean",                       ["scripts/2_cleaning.ipynb"]),
        ("4  coverage table",              ["scripts/3.1_data_coverage.ipynb"]),
        ("5  labeling pass 1",             [os.path.relpath(p, ROOT) for p in labeling("labeling_1")]),
        ("6  labeling pass 2",             [os.path.relpath(p, ROOT) for p in labeling("labeling_2")]),
        ("7  join customers",              ["scripts/4.1_joining_customers.ipynb"]),
        ("8  modeling prep",               ["scripts/4_modeling_prep.ipynb"]),
        ("9  aggregate",                   ["scripts/4.0_modeling_prep_2.ipynb"]),
        ("10 format weather + inflation",  ["scripts/5_format_weather_and_inflation_data.R"]),
        ("11 join weather + inflation",    ["scripts/5_add_weather_inflation_holidays.R"]),
    ]
    return s


def run_notebook(rel):
    import nbformat
    from nbclient import NotebookClient
    nb = nbformat.read(os.path.join(ROOT, rel), as_version=4)
    client = NotebookClient(nb, timeout=14400, kernel_name="python3",
                            resources={"metadata": {"path": ROOT}},
                            allow_errors=True)
    client.execute()
    errs = [o for c in nb.cells if c.cell_type == "code"
            for o in c.get("outputs", []) if o.get("output_type") == "error"]
    out = os.path.join(ROOT, "run_logs")
    os.makedirs(out, exist_ok=True)
    nbformat.write(nb, os.path.join(out, os.path.basename(rel)))
    return len(errs)


def run_r(rel):
    p = subprocess.run(["Rscript", rel], cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if p.returncode:
        sys.stderr.write(p.stderr.decode()[-2000:])
    return p.returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="start", type=int, default=1, help="resume from this step")
    ap.add_argument("--list", action="store_true", help="show the steps and exit")
    a = ap.parse_args()

    st = steps()
    if a.list:
        for i, (name, files) in enumerate(st, 1):
            print(f"  {i:>2}. {name:32s} {len(files)} file(s)")
        return 0

    if not os.path.isdir(os.path.join(ROOT, "data", "0_data_excel")):
        sys.exit("data/0_data_excel/ not found — run this from the repo root.")

    t0 = time.time()
    failed = []
    for i, (name, files) in enumerate(st, 1):
        if i < a.start:
            continue
        print(f"\n=== step {name}", flush=True)
        for rel in files:
            t = time.time()
            if rel.endswith(".R"):
                rc = run_r(rel)
                bad = rc != 0
                note = f"exit {rc}"
            else:
                n = run_notebook(rel)
                bad = False           # notebooks may fail in diagnostic cells; data still writes
                note = "clean" if n == 0 else f"{n} cell error(s)"
            if bad:
                failed.append(rel)
            print(f"    {os.path.basename(rel):44s} {note:16s} {time.time()-t:5.0f}s", flush=True)

    print(f"\ndone in {(time.time()-t0)/60:.1f} min")
    if failed:
        print("FAILED:", *failed, sep="\n  ")
        return 1
    print("\nOutput is in data/4_data_parquet_modeling/external_variables/")
    print("Check you reproduced it:  git status --porcelain -- data/")
    print("Executed notebooks were saved to run_logs/ if you need to inspect a cell error.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
