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
    try:
        client.execute()
    except Exception as e:                       # kernel died, timeout, etc.
        return [(-1, type(e).__name__, str(e)[:200])]
    errs = []
    for i, c in enumerate(nb.cells):
        if c.cell_type != "code":
            continue
        for o in c.get("outputs", []):
            if o.get("output_type") == "error":
                errs.append((i, o.get("ename"), " ".join(o.get("evalue", "").split())[:160]))
    out = os.path.join(ROOT, "run_logs")
    os.makedirs(out, exist_ok=True)
    nbformat.write(nb, os.path.join(out, os.path.basename(rel)))
    return errs


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
    hard = []          # stopped the pipeline
    soft = []          # cells failed but the step still produced output
    for i, (name, files) in enumerate(st, 1):
        if i < a.start:
            continue
        print(f"\n=== step {name}", flush=True)
        for rel in files:
            t = time.time()
            if rel.endswith(".R"):
                rc = run_r(rel)
                note = "clean" if rc == 0 else f"EXIT {rc}"
                if rc:
                    hard.append((rel, f"Rscript exited {rc}"))
            else:
                errs = run_notebook(rel)
                if errs and errs[0][0] == -1:
                    note = "DID NOT RUN"
                    hard.append((rel, f"{errs[0][1]}: {errs[0][2]}"))
                elif errs:
                    note = f"{len(errs)} cell error(s)"
                    c, en, ev = errs[0]
                    soft.append((rel, f"first at cell {c}: {en}: {ev}"))
                else:
                    note = "clean"
            print(f"    {os.path.basename(rel):44s} {note:16s} {time.time()-t:5.0f}s", flush=True)

    outdir = os.path.join(ROOT, "data", "4_data_parquet_modeling", "external_variables")
    produced = sum(len(f) for _, _, f in os.walk(outdir)) if os.path.isdir(outdir) else 0

    print(f"\n{'='*66}")
    print(f"done in {(time.time()-t0)/60:.1f} min")
    print(f"output files in external_variables/: {produced}")

    if hard:
        print(f"\nFAILED — {len(hard)} step(s) did not run:")
        for rel, why in hard:
            print(f"  {rel}\n      {why}")
        print("\nFix these and resume with:  python run_pipeline.py --from N")
        return 1

    if soft:
        print(f"\n{len(soft)} notebook(s) had cell errors but still wrote their output:")
        for rel, why in soft:
            print(f"  {os.path.basename(rel):40s} {why}")
        print("\n  These are known: several labeling notebooks fail in diagnostic")
        print("  cells that run after their data writes. Full notebooks in run_logs/.")

    if produced == 0:
        print("\nFAILED — no output was produced.")
        return 1

    print("\nOutput: data/4_data_parquet_modeling/external_variables/")
    print("Verify:  git status --porcelain -- data/     (clean = reproduced)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
