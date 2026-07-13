#!/usr/bin/env python3
"""Agent-assisted PHP monolith cleanup — candidate tiering.

Cross-references Psalm `UnusedClass` candidates against a repo-wide usage /
dependency signal (a lightweight "Project Unravel" analog built with ripgrep)
and assigns each candidate a confidence tier:

  Tier A  no references found anywhere            -> safe removal candidate
  Tier B  referenced from other PHP / test only   -> manual review required
  Tier C  dynamically wired (ORM / DI / config /  -> DO NOT remove
          naming-convention / cross-component)

Usage:
    php -d memory_limit=-1 library/vendor/bin/psalm \\
        --config=library/psalm-unused.xml --no-cache \\
        --report=psalm-unused.json --report-show-info=false || true
    python3 cleanup-tools/tier_candidates.py \\
        --repo . --report psalm-unused.json --component library \\
        --out-csv unused_candidates.csv --out-json unused_candidates.json
"""
import argparse
import collections
import csv
import json
import os
import re
import subprocess

CONFIG_EXT = (".yaml", ".yml", ".xml", ".twig", ".json", ".neon", ".ini", ".conf")


def rg_count(pattern, repo, whole_word=False, extra_globs=None):
    args = ["rg", "--no-messages", "-c", "-g", "!vendor/**", "-g", "!**/vendor/**"]
    for g in (extra_globs or []):
        args += ["-g", g]
    if whole_word:
        args.append("-w")
    args += [pattern, repo]
    out = subprocess.run(args, capture_output=True, text=True)
    files = []
    for line in out.stdout.splitlines():
        try:
            path, cnt = line.rsplit(":", 1)
            files.append((path, int(cnt)))
        except ValueError:
            continue
    return files


def classify(fqcn, filepath, short, refs_outside_files):
    p = filepath.lower()
    name = short
    # Convention-based DI resolution: ivoz-core's DtoAssembler service factory
    # builds the assembler FQCN as a runtime string
    # (str_replace('Domain\\Model','Domain\\Assembler', entity) . 'DtoAssembler')
    # and pulls it from the container -> never referenced statically anywhere.
    if name.endswith("DtoAssembler") and "domain/assembler" in p:
        return "C", "Resolved by naming convention via ivoz-core DtoAssembler factory (runtime string-built FQCN)"
    if "persistence/doctrine" in p or name.endswith("DoctrineRepository"):
        return "C", "Doctrine repository (wired via ORM repositoryClass / EntityManager)"
    if "datafixtures" in p or name.endswith(("Fixtures", "Fixture")):
        return "C", "Data fixture (loaded by fixtures loader by name)"
    if name.endswith("Command") or "/command/" in p:
        return "C", "Console command (registered/invoked dynamically)"
    if name.endswith(("EventSubscriber", "Subscriber", "EventListener", "Listener")):
        return "C", "Event subscriber/listener (DI-tagged, dispatched dynamically)"
    if "migrations" in p or re.match(r"Version\d+", name):
        return "C", "Doctrine migration (run by migration framework)"
    if name.endswith("Controller") or "/controller/" in p:
        return "C", "Controller (referenced by route string)"
    if name.endswith("Voter"):
        return "C", "Security voter (DI-tagged)"
    if any(f.lower().endswith(CONFIG_EXT) for f, _ in refs_outside_files):
        return "C", "Referenced from config/template/DI file (string wiring)"
    php_refs = [f for f, _ in refs_outside_files if f.lower().endswith(".php")]
    if php_refs:
        return "B", f"Short-name referenced in {len(php_refs)} other PHP file(s) (dynamic use / other component?)"
    if name.startswith("Fake") or "/spec/" in p or "/tests/" in p or name.endswith("Test"):
        return "B", "Test double / test-only class (verify test usage before removal)"
    if name.endswith(("Interface", "Trait", "Abstract")) or name.startswith("Abstract"):
        return "B", "Interface/trait/abstract (may be implemented dynamically)"
    return "A", "No references found anywhere (safe removal candidate)"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="repo root")
    ap.add_argument("--report", required=True, help="psalm JSON report")
    ap.add_argument("--component", default="library",
                    help="component dir the psalm report file paths are relative to")
    ap.add_argument("--out-csv", default="unused_candidates.csv")
    ap.add_argument("--out-json", default="unused_candidates.json")
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    comp = os.path.join(repo, args.component)
    report = json.load(open(args.report))
    unused = [d for d in report if d["type"] == "UnusedClass"]

    rows = []
    for d in unused:
        m = re.search(r"Class ([\\\w]+) is never used", d["message"])
        if not m:
            continue
        fqcn = m.group(1)
        short = fqcn.split("\\")[-1]
        own_file = os.path.abspath(os.path.join(comp, d["file_name"]))

        word_refs = rg_count(short, repo, whole_word=True,
                             extra_globs=["!**/psalm-unused.json", "!**/unused_candidates.*"])
        fqcn_refs = rg_count(fqcn.replace("\\", "\\\\"), repo)

        outside = {}
        for f, n in word_refs + fqcn_refs:
            if os.path.abspath(f) != own_file:
                outside[f] = max(outside.get(f, 0), n)
        outside_list = list(outside.items())

        tier, reason = classify(fqcn, d["file_name"], short, outside_list)
        rows.append({
            "tier": tier,
            "fqcn": fqcn,
            "file": d["file_name"],
            "refs_outside_own_file": sum(n for _, n in outside_list),
            "ref_files": len(outside_list),
            "reason": reason,
        })

    by_tier = collections.Counter(r["tier"] for r in rows)
    print(f"Total UnusedClass candidates: {len(rows)}")
    for t in ("A", "B", "C"):
        print(f"  Tier {t}: {by_tier.get(t, 0)}")

    with open(args.out_csv, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["tier", "fqcn", "file",
                                           "refs_outside_own_file", "ref_files", "reason"])
        w.writeheader()
        for r in sorted(rows, key=lambda r: (r["tier"], -r["refs_outside_own_file"])):
            w.writerow(r)
    json.dump(rows, open(args.out_json, "w"), indent=2)
    print(f"Wrote {args.out_csv} and {args.out_json}")


if __name__ == "__main__":
    main()
