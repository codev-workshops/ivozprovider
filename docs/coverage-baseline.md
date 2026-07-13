# PHP backend test coverage baseline

This document records the **line coverage** of the PHP backend components,
measured by reproducing the CI test environment described in the `Jenkinsfile`
(`prepare-backend`, `orm`, `phpspec`, `api-*` stages).

Target: **>= 85% line coverage per component and combined.**

## How coverage is generated

```bash
# One-time environment (see "Environment notes" below)
tests/docker/bin/prepare-composer-deps        # composer install for every component
tests/docker/bin/prepare-fixtures             # build sqlite fixtures (schema + rest apps)
web/rest/platform/bin/generate-keys --test    # JWT test keys

export XDEBUG_MODE=coverage

# library (phpspec)
library/bin/test-phpspec-with-coverage        # -> library/spec/coverage/coverage.php

# schema (PHPUnit, DB integration)
schema/bin/test-orm-with-coverage             # -> schema/tests/coverage/coverage.php

# rest apis + recordings (PHPUnit)
web/rest/<c>/vendor/bin/phpunit --coverage-php tests/coverage/coverage.php   # c in brand/client/user/platform
microservices/recordings: ../../schema/vendor/bin/phpunit --coverage-php tests/coverage/coverage.php

# combined
library/bin/combine-coverage                  # -> combined-coverage/ (+ prints % )

# quick per-report percentage
library/bin/coverage-percent <label> <coverage.php> [...]
```

## Baseline (branch `code-cleanup`, initial measurement)

Two different whitelists are in play, so components are grouped by what they
measure:

### Components whitelisting the shared `library/Ivoz` code base

| Component            | Test suite            | Line coverage        |
|----------------------|-----------------------|----------------------|
| library              | phpspec               | 21.21% (2581/12170)  |
| schema               | PHPUnit (ORM)         | 40.65% (4908/12074)  |
| microservices/recordings | PHPUnit           | 0.00%  (0/11990) [1] |
| **union of the above** | combine-coverage    | **49.66% (6049/12181)** |

### REST API components whitelisting their own `src`

| Component            | Test suite            | Line coverage        |
|----------------------|-----------------------|----------------------|
| web/rest/platform    | PHPUnit               | n/a — 0 PHPUnit tests present |
| web/rest/brand       | PHPUnit               | 2.64% (14/531)       |
| web/rest/client      | PHPUnit               | 2.41% (14/581)       |
| web/rest/user        | PHPUnit               | 4.65% (16/344)       |

### Combined report (`library/bin/combine-coverage`, all reports merged)

**45.39% (6093/13424 lines)**

[1] The recordings PHPUnit suite currently has a failing test and records no
    lines against the `library/Ivoz` whitelist.

## Tooling / environment issues found while establishing the baseline

The task premises assumed a working coverage pipeline; several parts were broken
and had to be repaired to obtain any numbers:

1. **phpspec coverage extension namespace.** `library/phpspec.yml` referenced
   `LeanPHP\PhpSpec\CodeCoverage\CodeCoverageExtension`, but the installed
   dependency (`friends-of-phpspec/phpspec-code-coverage` v6) provides
   `FriendsOfPhpSpec\PhpSpec\CodeCoverage\CodeCoverageExtension`. Fixed in
   `library/phpspec.yml`.

2. **`schema/bin/test-orm-with-coverage` dropped its coverage flags.** It called
   `test-orm --coverage-html ... --coverage-php ...`, but `test-orm` never
   forwarded arguments to PHPUnit, so no coverage was ever produced. Rewritten
   to invoke `vendor/bin/phpunit` with the coverage flags directly.

3. **`library/bin/combine-coverage` could not run.** It did `new CodeCoverage()`
   with no arguments, which fatals on the installed `sebastian/code-coverage`
   (constructor requires a driver + filter), and it only referenced the three
   REST *Behat* feature reports (see next point). Rewritten to merge into the
   first available report, skip missing files, and include every component.

4. **REST Behat coverage collection is not available.** `behat.yml.dist` and the
   `bin/test-api-with-coverage` scripts reference
   `Ivoz\Api\Behat\Context\CoverageContext`, but that class no longer exists in
   the installed `irontec/ivoz-api` package, so the Behat `.feature` suites (the
   suites that exercise the bulk of the REST `src` and library code) currently
   record no coverage. REST `src` coverage above therefore reflects only the
   PHPUnit `tests/` suites.

5. **No `dev:test:coverage:ci` composer scripts exist** in any component's
   `composer.json` (Phase 5 assumed they were present).

### Environment reproduction notes (not committed; needed to run the suites)

* PHP **8.2** (not 8.3) — matches the CI Debian Bookworm image; 8.3 changes some
  signatures.
* Composer **2.5.x** — composer 2.10 fatals loading `symfony/flex` v1.
* `ext-redis` **5.3.x** — the sury 6.3 build has typed `Redis::blPop()` etc. that
  are incompatible with `FakeRedisMasterFactory`'s anonymous subclass.
* `variables_order = "EGPCS"` in `php.ini` so `$_ENV['DISABLE_FK']` is honoured
  by the sqlite session-init listener during fixture loading.
* `XDEBUG_MODE=coverage` must be set for any coverage run.
* The `core:prepare:database` command must run against a **cold** Symfony cache
  (`rm -rf schema/var/cache/*`); a warm cache triggers an "Unknown database type"
  error from the schema tool.

## Planned exclusions

Large portions of `library/Ivoz` are generated code (entity `*Abstract` /
`*Trait` / DTO scaffolding) and infrastructure adapters that require external
services (CGRateS, Asterisk AMI, Redis, filesystem/S3). Where reaching 85% is
infeasible without hollow tests, these will be documented here and added to the
relevant phpunit/phpspec coverage exclusion configuration rather than padded
with meaningless assertions. Concrete exclusions will be listed as the work in
Phases 2-4 progresses.
