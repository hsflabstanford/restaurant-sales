import pandas as pd
import numpy as np
import pytest
from pandas.testing import assert_series_equal

from tools.rolling import rolling_window_sum

NAME = "sum_1d"

# Spec: rolling window is [t-1D, t) — EXCLUDES the current timestamp, INCLUDES exactly 24h ago.

# ─────────────────────────────────────────
# Helpers
# —————————————————————————————————————————
def df_from_pairs(pairs):
    """
    Build a DataFrame from list of (timestamp_str, qty) pairs.
    - Assumes label is binary and always 1.
    - Sorts by created_at (irregular spacing ok; duplicates allowed).
    """
    df = (
        pd.DataFrame(pairs, columns=["created_at", "qty"])
        .assign(created_at = lambda df: pd.to_datetime(df["created_at"]))
        .sort_values("created_at")
        .assign(label = 1)  # binary label
        .set_index("created_at")
        .rename_axis("created_at"))
    return df

def expected_series(mapping):
    """
    Build a Series from {timestamp_str: expected_value}.
    Index is unique timestamps, seconds-level, sorted.
    """
    s = (
        pd.Series(mapping, dtype="float64")
        .rename(NAME)
        .rename_axis("created_at")
        .pipe(lambda x: x.set_axis(pd.to_datetime(x.index)))
        .sort_index())
    return s

# ─────────────────────────────────────────
# Cases
# ─────────────────────────────────────────

# ---------------- Case 1: Simple irregular with duplicates ----------------
# time                         qty
CASE1_INPUT = [
    ("2025-01-10 12:00:00", 1),
    ("2025-01-10 12:00:00", 1),
    ("2025-01-10 12:00:05", 2),
    ("2025-01-10 12:30:00", 1),
    ("2025-01-11 08:00:00", 1),
    ("2025-01-11 11:59:50", 3),
    ("2025-01-11 12:00:01", 1),
]
# Aggregating duplicates ⇒
# 12:00:00 → 2; 12:00:05 → 2; 12:30 → 1; 08:00 → 1; 11:59:50 → 3; 12:00:01 → 1
CASE1_EXPECTED = {
    "2025-01-10 12:00:00": 0.0,
    "2025-01-10 12:00:05": 2.0,
    "2025-01-10 12:30:00": 4.0,
    "2025-01-11 08:00:00": 5.0,
    "2025-01-11 11:59:50": 6.0,
    "2025-01-11 12:00:01": 7.0,
}

# ---------------- Case 2: Large gaps ----------------
# time                         qty
CASE2_INPUT = [
    ("2025-02-01 08:00:00", 10),
    ("2025-02-01 14:00:01", 1),
    ("2025-02-02 07:59:00", 2),
    ("2025-02-03 08:01:00", 1),
]
CASE2_EXPECTED = {
    "2025-02-01 08:00:00": 0.0,
    "2025-02-01 14:00:01": 10.0,
    "2025-02-02 07:59:00": 11.0,
    "2025-02-03 08:01:00": 0.0,
}

# ---------------- Case 3: 24h boundary behavior ----------------
# time                         qty
CASE3_INPUT = [
    ("2025-04-19 10:00:00", 1),
    ("2025-04-19 10:00:01", 1),
    ("2025-04-20 10:00:00", 5),
    ("2025-04-20 10:00:01", 1),
]
CASE3_EXPECTED = {
    "2025-04-19 10:00:00": 0.0,
    "2025-04-19 10:00:01": 1.0,
    "2025-04-20 10:00:00": 2.0,  # includes 19th 10:00:00 and 10:00:01; excludes current 5
    "2025-04-20 10:00:01": 6.0,  # includes 19th 10:00:01 and 20th 10:00:00
}

# ---------------- Case 4: Many duplicates at a few timestamps ----------------
# time                         qty
CASE4_INPUT = [
    ("2025-05-01 12:00:00", 1),
    ("2025-05-01 12:00:00", 1),
    ("2025-05-01 12:00:00", 1),
    ("2025-05-01 12:00:10", 3),
    ("2025-05-01 12:00:10", 1),
    ("2025-05-02 11:59:59", 1),
    ("2025-05-02 11:59:59", 1),
    ("2025-05-02 11:59:59", 2),
    ("2025-05-02 11:59:59", 1),
]
# Aggregated: 12:00:00→3, 12:00:10→4, next day 11:59:59→5
CASE4_EXPECTED = {
    "2025-05-01 12:00:00": 0.0,
    "2025-05-01 12:00:10": 3.0,
    "2025-05-02 11:59:59": 7.0,
}

# ---------------- Case 5: NaNs (ignored by sum) ----------------
# time                         qty
CASE5_INPUT = [
    ("2025-06-01 09:00:00", 1),
    ("2025-06-01 09:00:00", np.nan),
    ("2025-06-01 09:01:00", np.nan),
    ("2025-06-02 08:00:00", 2),
    ("2025-06-02 09:00:00", 1),
]
CASE5_EXPECTED = {
    "2025-06-01 09:00:00": 0.0,
    "2025-06-01 09:01:00": 1.0,
    "2025-06-02 08:00:00": 1.0,
    "2025-06-02 09:00:00": 3.0,
}

# ---------------- Case 6: Multiple days, irregular ----------------
# time                         qty
CASE6_INPUT = [
    ("2025-07-10 00:00:00", 1),
    ("2025-07-10 01:00:00", 1),
    ("2025-07-10 02:00:00", 2),
    ("2025-07-10 23:59:50", 1),
    ("2025-07-11 00:10:00", 1),
    ("2025-07-11 01:00:00", 1),
    ("2025-07-11 23:59:55", 3),
    ("2025-07-12 00:00:00", 2),
]
CASE6_EXPECTED = {
    "2025-07-10 00:00:00": 0.0,
    "2025-07-10 01:00:00": 1.0,
    "2025-07-10 02:00:00": 2.0,
    "2025-07-10 23:59:50": 4.0,
    "2025-07-11 00:10:00": 4.0,
    "2025-07-11 01:00:00": 5.0,
    "2025-07-11 23:59:55": 2.0,
    "2025-07-12 00:00:00": 5.0,
}

# Bundle for parametrization
ALL_CASES = {
    "case1": (CASE1_INPUT, CASE1_EXPECTED),
    "case2": (CASE2_INPUT, CASE2_EXPECTED),
    "case3": (CASE3_INPUT, CASE3_EXPECTED),
    "case4": (CASE4_INPUT, CASE4_EXPECTED),
    "case5": (CASE5_INPUT, CASE5_EXPECTED),
    "case6": (CASE6_INPUT, CASE6_EXPECTED),
}

# ─────────────────────────────────────────
# Tests
# ─────────────────────────────────────────
@pytest.mark.parametrize("case_key", list(ALL_CASES.keys()))
def test_rolling_sum_fixed(case_key):
    pairs, expected_map = ALL_CASES[case_key]
    df = df_from_pairs(pairs)
    expected = expected_series(expected_map)

    got = rolling_window_sum(
        df.copy(),
        label_col="label",
        count_col="qty",
        name=NAME,
        lookback_period=1,
        lookback_unit="D",
    ).astype(float)

    # helpful failure diagnostics
    assert list(got.index) == list(expected.index), (
        f"[{case_key}] Index mismatch.\n"
        f"Input pairs (time, qty):\n"
        + "\n".join(f"  {t}  {q}" for t, q in pairs)
        + f"\nGot index:\n  {list(got.index)}\nExpected index:\n  {list(expected.index)}"
    )

    try:
        assert_series_equal(got.sort_index(), expected.sort_index(), check_dtype=False, check_names=True)
    except AssertionError as e:
        raise AssertionError(
            f"[{case_key}] Values mismatch.\n"
            f"Input pairs (time, qty):\n"
            + "\n".join(f"  {t}  {q}" for t, q in pairs)
            + f"\nGot:\n{got.sort_index().to_string()}\n\nExpected:\n{expected.sort_index().to_string()}"
        ) from e
