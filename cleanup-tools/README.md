# Agent-assisted PHP monolith cleanup — tooling

A repeatable workflow for using **Psalm unused-code analysis** plus a
**repo-wide dependency/usage signal** to safely identify dead classes in the
IvozProvider monolith, and to classify each candidate by removal risk before
anything is deleted.

This is a *pilot* to evaluate whether an agent can reason over static-analysis
and dependency datasets to drive cleanup with a low regression rate.

## Why two signals?

Psalm's `findUnusedCode` reports a class as `UnusedClass` when nothing in the
**analyzed component** references it statically. In a DI-heavy PHP monolith that
is *necessary but not sufficient*, because classes are reached at runtime by:

- **Doctrine ORM** — repositories wired via entity `repositoryClass`.
- **DI naming conventions** — e.g. ivoz-core's `DtoAssembler` factory builds the
  assembler FQCN as a runtime string
  (`str_replace('Domain\Model','Domain\Assembler', $entity) . 'DtoAssembler'`)
  and pulls it from the container. The class name never appears statically.
- **Config / template string wiring** — YAML/XML DI, Twig, routing.
- **Cross-component usage** — `library/` classes consumed by `web/rest/*` and
  `microservices/*`, which are *separate* Composer projects each analyzed with
  their own `psalm.xml`. Component-scoped Psalm can't see these edges.

So we cross-reference Psalm candidates against a repo-wide usage graph (ripgrep
over short-name + FQCN string references, across every component and config
file) — the "Project Unravel" analog — and only then tier them.

## Usage

```bash
# from repo root
./cleanup-tools/run_unused_report.sh library
```

Outputs:
- `psalm-unused.json` — raw Psalm report (the "Unused Classes dataset").
- `unused_candidates.csv` / `.json` — every `UnusedClass` candidate with its
  reference counts and assigned tier.

`library/psalm-unused.xml` is a dedicated Psalm config that *un-suppresses*
`UnusedClass` / `PossiblyUnusedMethod` (the default `library/psalm.xml`
suppresses them) and silences unrelated issue types so the report is focused.

## Tiers

| Tier | Meaning | Action |
|------|---------|--------|
| **A** | No references found anywhere | Safe removal candidate — delete in a small PR, then run Psalm + full test suite. |
| **B** | Referenced from other PHP / tests only | Manual review — often cross-component usage (`web/rest`, `microservices`) that library-scoped Psalm missed. |
| **C** | Dynamically wired (ORM / DI / config / naming-convention / cross-component) | **Do not remove.** |

## Pilot finding (component = `library`)

Of **256** `UnusedClass` candidates Psalm reported for `library/Ivoz`:

- **Tier A: 0**
- **Tier B: 16** (all verified to be used by `web/rest/*` or `microservices/*`)
- **Tier C: 240** (157 Doctrine repositories, 34 convention-resolved
  DtoAssemblers, 48 config/DI string-wired, 1 event listener)

Conclusion: on this codebase, **zero** of Psalm's unused-class candidates are
blindly safe to delete — every one is reachable dynamically. This is exactly why
the maintainers suppress `UnusedClass` in `psalm.xml`, and why a dependency
dataset is essential alongside Psalm. For meaningful dead-code wins here you
would analyze **all components together** (unified project) and incorporate a
DI-container-aware dependency graph rather than component-scoped static analysis.
```
