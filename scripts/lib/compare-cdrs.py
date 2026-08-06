#!/usr/bin/env python3
"""Diff two sets of normalised CDRs produced by scripts/extract-cdrs.

Reports, per table:

  * call count, in total and per direction;
  * per-call differences - a call present in one run and not the other, or the
    same call with a different duration;
  * billing differences - cost, price, and the carrier/destination/rating plan a
    call was billed against.

Calls are matched on who called whom rather than on id, because ids are not
comparable across two independent runs. Where a run contains several calls
between the same pair, they are paired up in sorted order.
"""

import csv
import os
import sys
from collections import Counter, defaultdict

TABLES = ("kam_users_cdrs", "kam_trunks_cdrs", "billable_calls")

# Fields that describe what a call cost. A difference in any of them is a
# billing difference, reported separately from a difference in duration.
BILLING_FIELDS = (
    "cost",
    "price",
    "carrierName",
    "destinationName",
    "ratingPlanName",
    "carrierId",
    "destinationId",
    "ratingPlanGroupId",
)

IDENTITY_FIELDS = ("direction", "caller", "callee")


def read(path):
    if not os.path.exists(path):
        return None
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def key(row):
    return tuple(row.get(field, "") for field in IDENTITY_FIELDS)


def group(rows):
    grouped = defaultdict(list)
    for row in rows:
        grouped[key(row)].append(row)
    for calls in grouped.values():
        calls.sort(key=lambda row: row.get("duration", ""))
    return grouped


def describe(call_key):
    direction, caller, callee = call_key
    return "{} {} -> {}".format(direction or "?", caller or "?", callee or "?")


def compare_table(name, baseline, candidate, report):
    if baseline is None or candidate is None:
        missing = "baseline" if baseline is None else "candidate"
        report.append("{}: no {} extract".format(name, missing))
        return False

    ok = True
    if len(baseline) != len(candidate):
        ok = False
        report.append(
            "{}: call count {} -> {}".format(name, len(baseline), len(candidate))
        )

    for direction in sorted(
        set(row.get("direction", "") for row in baseline + candidate)
    ):
        before = sum(1 for row in baseline if row.get("direction", "") == direction)
        after = sum(1 for row in candidate if row.get("direction", "") == direction)
        if before != after:
            ok = False
            report.append(
                "{}: {} calls {} -> {}".format(name, direction or "(none)", before, after)
            )

    left, right = group(baseline), group(candidate)
    for call_key in sorted(set(left) | set(right)):
        mine, theirs = left.get(call_key, []), right.get(call_key, [])
        if len(mine) != len(theirs):
            ok = False
            report.append(
                "{}: {}: {} call(s) -> {}".format(
                    name, describe(call_key), len(mine), len(theirs)
                )
            )
        for before, after in zip(mine, theirs):
            if before.get("duration") != after.get("duration"):
                ok = False
                report.append(
                    "{}: {}: duration {}s -> {}s".format(
                        name, describe(call_key),
                        before.get("duration"), after.get("duration"),
                    )
                )
            for field in BILLING_FIELDS:
                if field in before and before.get(field) != after.get(field):
                    ok = False
                    report.append(
                        "{}: {}: {} {} -> {}".format(
                            name, describe(call_key), field,
                            before.get(field), after.get(field),
                        )
                    )
    return ok


def main():
    baseline_dir, candidate_dir = sys.argv[1], sys.argv[2]

    report = []
    results = Counter()
    for name in TABLES:
        ok = compare_table(
            name,
            read(os.path.join(baseline_dir, name + ".csv")),
            read(os.path.join(candidate_dir, name + ".csv")),
            report,
        )
        results["same" if ok else "different"] += 1
        print("{:<18}  {}".format(name, "same" if ok else "DIFFERENT"))

    if report:
        print()
        for line in report:
            print("  " + line)

    print()
    print("{} of {} tables match".format(results["same"], len(TABLES)))
    sys.exit(1 if results["different"] else 0)


if __name__ == "__main__":
    main()
