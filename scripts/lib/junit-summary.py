#!/usr/bin/env python3
"""Merge the per-scenario BBS JUnit files into one summary and report.

A scenario that produced no JUnit file at all - bbs crashed, or the scenario
timed out before it could write one - is reported as an error rather than
quietly dropped, so the scenario count always matches the scenario files on
disk.
"""

import argparse
import glob
import os
import sys
import xml.etree.ElementTree as ET


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", required=True, help="directory holding results_*.xml")
    parser.add_argument("--scenarios", required=True, help="directory holding *test-*.yaml")
    parser.add_argument("--known-failures", help="YAML list of known-failing scenario names")
    parser.add_argument("--output", required=True, help="merged JUnit file to write")
    return parser.parse_args()


def load_known_failures(path):
    """Read the known-failure list.

    Deliberately a hand-rolled reader for a `name: reason` mapping rather than a
    PyYAML dependency, so the summary runs on a bare python3.
    """
    known = {}
    if not path or not os.path.exists(path):
        return known
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#", 1)[0].rstrip()
            if not line or line.startswith(" ") or ":" not in line:
                continue
            name, reason = line.split(":", 1)
            known[name.strip()] = reason.strip().strip('"')
    return known


def read_attempts(results_dir, name):
    path = os.path.join(results_dir, "attempts_{}.txt".format(name))
    try:
        with open(path, encoding="utf-8") as handle:
            return int(handle.read().strip())
    except (OSError, ValueError):
        return 1


def read_scenario(results_dir, name):
    """Return (cases, ok) for one scenario, where cases is a list of elements."""
    path = os.path.join(results_dir, "results_{}.xml".format(name))
    if not os.path.exists(path):
        case = ET.Element("testcase", {"name": name, "classname": name})
        error = ET.SubElement(case, "error", {"message": "bbs produced no JUnit output"})
        error.text = "no {} - the scenario did not complete".format(path)
        return [case], False

    tree = ET.parse(path)
    cases = tree.getroot().iter("testcase")
    ok = True
    collected = []
    for case in cases:
        case.set("classname", name)
        if case.find("failure") is not None or case.find("error") is not None:
            ok = False
        collected.append(case)
    if not collected:
        case = ET.Element("testcase", {"name": name, "classname": name})
        ET.SubElement(case, "error", {"message": "empty JUnit output"})
        return [case], False
    return collected, ok


def main():
    args = parse_args()
    known = load_known_failures(args.known_failures)

    names = sorted(
        os.path.basename(path)[: -len(".yaml")]
        for path in glob.glob(os.path.join(args.scenarios, "*test-*.yaml"))
    )
    if not names:
        sys.exit("no scenarios found in {}".format(args.scenarios))

    suite = ET.Element("testsuite", {"name": "bbs"})
    passed, failed, known_failed, unexpected_pass = [], [], [], []
    attempts = {}

    for name in names:
        cases, ok = read_scenario(args.results, name)
        attempts[name] = read_attempts(args.results, name)
        for case in cases:
            suite.append(case)
        if ok:
            (unexpected_pass if name in known else passed).append(name)
        else:
            (known_failed if name in known else failed).append(name)

    suite.set("tests", str(len(names)))
    suite.set("failures", str(len(failed) + len(known_failed)))
    suite.set("errors", "0")

    root = ET.ElementTree(ET.Element("testsuites"))
    root.getroot().append(suite)
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    root.write(args.output, encoding="utf-8", xml_declaration=True)

    width = max(len(name) for name in names)
    for name in names:
        if name in passed and attempts[name] > 1:
            status = "FLAKY  passed on attempt {}".format(attempts[name])
        elif name in passed:
            status = "PASS"
        elif name in unexpected_pass:
            status = "PASS (listed as known-failing)"
        elif name in known_failed:
            status = "KNOWN-FAIL  {}".format(known[name])
        else:
            status = "FAIL"
        print("{:<{width}}  {}".format(name, status, width=width))

    print()
    flaky = [name for name in passed if attempts[name] > 1]
    print("scenarios:   {}".format(len(names)))
    print("passed:      {} ({} of them only on a retry)".format(
        len(passed) + len(unexpected_pass), len(flaky)))
    print("failed:      {}".format(len(failed)))
    print("known-fail:  {}".format(len(known_failed)))
    print("summary:     {}".format(args.output))

    if unexpected_pass:
        print()
        print("These now pass and should be removed from {}:".format(args.known_failures))
        for name in unexpected_pass:
            print("  {}".format(name))

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
