# Legacy baseline

Behaviour of the platform as it runs today, recorded on a docker-only machine
before any migration work. The numbers below are what the commands actually
printed, not a target.

## How it was produced

```bash
docker compose --profile tests down -v   # start from an empty database
./scripts/legacy-baseline up             # build, start, migrate, seed
./scripts/call-tests                     # run tests/bbs, merge JUnit, dump CDRs
```

`legacy-baseline up` brings up `data`, `redis`, `backend`, the four `portal-*`
services, `resolver`, `kamailio-users`, `kamailio-trunks`, `asterisk` and
`rtpengine`, waits for their healthchecks, lets `docker/backend/start.sh` run
`doctrine:migrations:migrate` over `schema/initial.sql`, loads
`tests/bbs/dataset.json` through the REST API (`scripts/seed-bbs-dataset`) and
points every proxy/application-server/media-relay row at the compose addresses
(`scripts/seed-proxy-addresses`).

The `portal-*` services bind-mount a sibling checkout of
[irontec/ivoz-ui](https://github.com/irontec/ivoz-ui); when `../ivoz-ui` is not
present `legacy-baseline` prints a warning and starts everything else (no call
test needs a portal).

## Recorded baseline: 45 of 48 SIP scenarios pass

Run of 2026-08-06, artifacts in `var/baseline/20260806T184410Z/`:

```
scenarios : 48 (45 passing, 3 failing)
assertions: 45/48 passed (0 failures, 3 errors, 0 skipped)
report    : var/baseline/20260806T184410Z/bbs-results.xml
```

Every scenario under `tests/bbs/` is executed; nothing is skipped or modified.
The three that do not pass are documented, with the reason each one showed, in
[known-failing.md](known-failing.md):

| scenario | reason |
| --- | --- |
| `1010-test-ddi-bounced-int` | international call needs the CGRateS rating engine, which is not part of this stack |
| `2405-test-huntgroup-all-complex` | `tests/bbs/dataset.json` puts alice + an external number in the complex hunt group, the scenario expects bob/charlie/dave |
| `2415-test-huntgroup-rr-complex` | same mismatch as above for the round-robin complex hunt group |

## CDRs

`scripts/call-tests` also dumps the call detail records of the run to
`var/baseline/<run tag>/cdrs.csv` (`scripts/extract-cdrs`), normalised so two
runs can be diffed: fixed column order, sorted rows, call-ids replaced by a
per-run sequence number, timestamps turned into offsets from the first call of
the run, and only the calls placed by that run.

The baseline run wrote 129 rows over `kam_users_cdrs`, `kam_trunks_cdrs` and
`BillableCalls`.

Two runs are compared with:

```bash
./scripts/compare-cdrs var/baseline/<legacy run>/cdrs.csv var/baseline/<new run>/cdrs.csv
```

which exits non-zero on any difference in call count, per-call duration or the
billing fields (price, cost, destination, rating plan, carrier). That is the
harness a migrated stack has to be judged against.

Comparing two consecutive runs of the legacy stack itself shows how much noise
to expect from the run-to-run variance of the scenarios: the second run
(`var/baseline/second/`) differed from the baseline by one call and two
durations, all of them on `1001 -> 600` (the IVR scenarios that
`tests/bbs/entrypoint.sh` retries and whose steps wait on DTMF timeouts):

```
- call count: 120 -> 119 (-1)
- users_cdr rows: 107 -> 106
- source=users_cdr direction=outbound caller=1001 callee=600 [#3]: duration 15s -> 12s
```

Everything else - including every billing field - was identical.

## Other suites

`./scripts/run-suites` drives the suites that already exist through
`tests/run-pipeline` (`library/bin/test-phpspec|test-phpstan|test-psalm|test-codestyle`,
`web/portal/<app>/bin/test-lint|test-i18n|test-build`) and runs
`tests/rest/postman-api-tests.json` with newman against the running backend.
It is not part of the recorded call baseline above.

`./scripts/run-suites backend` (phpspec, phpstan, psalm, codestyle) and
`./scripts/run-suites portals` (lint, i18n, build for the four portals) pass on
this checkout.

State of the REST collection on this stack (`./scripts/run-suites api`): the
59 requests all reach the backend, 38 of the 73 assertions fail. The collection
is in the Postman v1 format and predates the current API - it authenticates
with a hardcoded `Basic` credential (overridden by `run-suites` with a token
from `/api/platform/admin_login`, which fixes the 401s) and posts to
trailing-slash platform paths such as `POST /api/platform/brands/`, which the
current routes answer with a 404. Bringing it up to date is a separate job from
recording the call baseline, so it is reported as it is rather than rewritten.
