# PHP backend test coverage baseline

This document records the **line coverage** of the PHP backend components,
measured by reproducing the CI test environment described in the `Jenkinsfile`
(`prepare-backend`, `orm`, `phpspec`, `api-*` stages).

Target: **>= 85% line coverage per component and combined.**

## How coverage is generated

```bash
export XDEBUG_MODE=coverage

# library (phpspec, whitelist library/Ivoz)
library/bin/test-phpspec-with-coverage                # -> library/spec/coverage/coverage.php

# schema (PHPUnit ORM, DB integration, whitelist library/Ivoz)
schema/bin/test-orm-with-coverage --skip-db           # -> schema/tests/coverage/coverage.php

# rest apis (Behat, whitelist library/Ivoz + <app>/src)
web/rest/<c>/bin/test-api-with-coverage --skip-db     # -> web/rest/<c>/features/coverage/coverage.php

# recordings (PHPUnit, whitelist library/Ivoz)
microservices/recordings: XDEBUG_MODE=coverage ../../schema/vendor/bin/phpunit --coverage-php tests/coverage/coverage.php

# combined report (merges every report above)
library/bin/combine-coverage                          # -> combined-coverage/ (+ prints %)

# quick per-report percentage, optionally restricted to a path
library/bin/coverage-percent [--filter=<path-substring>] <label> <coverage.php> [...]
```

## Baseline (branch `code-cleanup`)

The REST suites are Behat feature suites that exercise the controllers, data
access control, DTOs and the shared `library/Ivoz` domain code through real HTTP
requests against the Symfony kernel. Coverage from those suites therefore counts
against both the component's own `src` and the shared `library/Ivoz` tree.

### Per-component line coverage of the component's own code

| Component                | Suite            | Coverage of own code            |
|--------------------------|------------------|---------------------------------|
| library (`library/Ivoz`) | phpspec          | 21.21% (2581/12170)             |
| schema (`library/Ivoz`)  | PHPUnit ORM      | 40.65% (4908/12074)             |
| web/rest/platform (`src`)| Behat            | 73.65% (218/296)                |
| web/rest/brand (`src`)   | Behat            | 70.20% (391/557)                |
| web/rest/client (`src`)  | Behat            | 79.66% (466/585)                |
| web/rest/user (`src`)    | Behat            | 73.51% (272/370)                |
| microservices/recordings (`library/Ivoz`) | PHPUnit | 0.00% (0/11990) [1]        |

### Shared `library/Ivoz` coverage, union of all suites

The library/schema/recordings suites plus all four REST Behat suites, merged and
restricted to `library/Ivoz`:

**74.51% (9076/12181 lines)**

### Combined report (`library/bin/combine-coverage`, everything merged)

**75.24% (10452/13891 lines)**

[1] The recordings PHPUnit suite currently has one failing/erroring test and
    records no lines against the `library/Ivoz` whitelist; see below.

## Gap to the 85% target

| Scope                    | Baseline | Gap to 85% |
|--------------------------|----------|------------|
| library/Ivoz (union)     | 74.51%   | +10.5 pts (~1280 lines) |
| platform src             | 73.65%   | +11.4 pts  |
| brand src                | 70.20%   | +14.8 pts  |
| client src               | 79.66%   | +5.3 pts   |
| user src                 | 73.51%   | +11.5 pts  |
| combined                 | 75.24%   | +9.8 pts   |

The remaining gap is closed in Phases 2-4 by adding targeted phpspec specs
(library domain models/services), expanding schema repository/entity tests, and
adding REST tests/feature scenarios, plus documenting exclusions for code that
cannot be meaningfully unit-tested (see below).

## Tooling / environment issues found and repaired

The coverage pipeline was broken in several places and had to be repaired before
any numbers could be produced:

1. **phpspec coverage extension namespace.** `library/phpspec.yml` referenced
   `LeanPHP\PhpSpec\CodeCoverage\CodeCoverageExtension`; the installed
   `friends-of-phpspec/phpspec-code-coverage` v6 provides
   `FriendsOfPhpSpec\PhpSpec\CodeCoverage\CodeCoverageExtension`.

2. **`schema/bin/test-orm-with-coverage` never produced coverage.** It passed
   `--coverage-*` flags to `test-orm`, which does not forward arguments to
   PHPUnit. Rewritten to call `vendor/bin/phpunit` with the coverage flags and
   `XDEBUG_MODE=coverage`.

3. **`library/bin/combine-coverage` could not run.** It constructed
   `new CodeCoverage()` with no arguments (fatal on the installed
   `sebastian/code-coverage`, whose constructor requires a driver + filter), and
   only referenced three non-existent REST feature reports. Rewritten to merge
   into the first available report, skip missing files, include every component,
   and print the combined percentage.

4. **REST Behat coverage collection was missing.** `behat.yml.dist` and the
   `bin/test-api-with-coverage` scripts referenced
   `Ivoz\Api\Behat\Context\CoverageContext`, which was removed from the
   `irontec/ivoz-api` package, so the Behat suites recorded no coverage and the
   `test-api-with-coverage` scripts `sed`-edited a non-existent `behat.yml`. A
   modern `Service\Behat\CoverageContext` (using the current
   `sebastian/code-coverage` API) was added to each REST app, wired into the
   default Behat profile, and left inert unless the `COVERAGE` env var is set.
   The `test-api-with-coverage` scripts were rewritten to run Behat with
   `COVERAGE=1 XDEBUG_MODE=coverage`.

5. **No `dev:test:coverage:ci` composer scripts exist** in any component's
   `composer.json`; the coverage gate is added fresh in Phase 5.

### Pre-existing test failures (not caused by these changes)

* `web/rest/platform` – `getInvoiceTemplatePreview.feature` (1 scenario) fails
  with HTTP 400 (invoice PDF preview requires a rendering backend not available
  in the test env).
* `web/rest/brand` – one analogous invoice-template scenario fails for the same
  reason.
* `microservices/recordings` – 1 of 2 PHPUnit tests errors (requires the
  recordings encoder / filesystem backend).

These do not prevent coverage generation (the Behat `AfterSuite` hook still
dumps the report).

### Environment reproduction notes (host config, not committed)

* PHP **8.2** (CI image), Composer **2.5.x** (2.10 fatals on `symfony/flex` v1),
  `ext-redis` **5.3.x** (newer typed `Redis::blPop()` breaks the fake Redis),
  `variables_order = "EGPCS"` (so `$_ENV['DISABLE_FK']` is honoured during
  fixture loading), `XDEBUG_MODE=coverage`, and a cold Symfony cache before
  `core:prepare:database` (`rm -rf schema/var/cache/*`).

## Planned / applied exclusions

Large parts of `library/Ivoz` are generated scaffolding (entity
`*Abstract`/`*Trait`, DTOs) and infrastructure adapters that require external
services (CGRateS, Asterisk AMI, Redis, S3/filesystem, PDF rendering). Where
reaching 85% would require hollow tests, those areas are documented here and
added to the relevant coverage exclusion configuration rather than padded with
meaningless assertions. Concrete exclusions are listed as Phases 2-4 progress.
