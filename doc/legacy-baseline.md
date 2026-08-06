# Legacy baseline

A whole IvozProvider - data, web, and the SIP/media plane - on one machine with
nothing but Docker, so that a change to any of it can be judged against how the
platform behaves today.

```
./scripts/legacy-baseline up     # bring the platform up and seed it
./scripts/call-tests             # run the BBS call scenarios
./scripts/extract-cdrs out/      # dump the resulting CDRs as normalised CSV
./scripts/test-all               # every other suite in the repository
```

## What is in the stack

`docker-compose.yml` adds four services to the existing data/redis/backend/portal
ones, all installed from `packages.irontec.com` rather than built here, so the
baseline is the packaged platform and not an approximation of it:

| service | package | address |
| --- | --- | --- |
| `kamailio-users` | `ivozprovider-kamailio-users` | 10.189.4.40 |
| `kamailio-trunks` | `ivozprovider-kamailio-trunks` | 10.189.4.41 |
| `asterisk` | `ivozprovider-asterisk` | 10.189.4.42 |
| `rtpengine` | `ivozprovider-rtpengine` | 10.189.4.43 |

Addresses are static because Kamailio's configuration is generated from the
database, and the database has to name the hosts.

Each Kamailio container runs `profiles/proxy/etc/kamailio/autoconf` - the script
the package ships, copied in unmodified - to generate `listeners.cfg` and
`ports.cfg` from `ProxyUsers`/`ProxyTrunks` at start, which is what
`kamailio@.service` does with `ExecStartPre` on a real node.

### Where the baseline differs from a packaged node

Three things are unavoidably different, and all of them are local service
inventory rather than anything a carrier or customer is configured to reach:

* `docker/mariadb/initdb/20-legacy-baseline.sql` points `ApplicationServers.ip`,
  `kam_rtpengine.url`, `ProxyUsers.ip` and `ProxyTrunks.ip` at the containers.
  `schema/initial.sql` seeds all of them as `127.0.0.1`, meaning "the one node
  everything runs on"; here they are separate containers. The advertised
  addresses - `ProxyTrunks.advertisedIp`, `ProxyUsers.advertisedIp`,
  `Companies.domain_users`, `Domains.domain` - are left exactly as seeded.
* `docker/redis/sentinel.conf` monitors the Redis container's address instead of
  `127.0.0.1`, so the master Sentinel hands out is reachable from the other
  containers.
* Asterisk's FastAGI listener is started with `socat` because the packaged unit
  relies on systemd socket activation, and rtpengine forwards in userspace
  because its kernel module cannot be built in a container.

There is no `ivozprovider-realtime` and no CGRateS. The realtime service is what
normally pushes cache reloads into the proxies as objects change, so
`scripts/seed-fixtures` issues `domain.reload`, `dialplan.reload`, `lcr.reload`
and the permissions reloads once at the end of the seed instead. CGRateS is what
rates a finished call, so `BillableCalls` stays empty - see "Known gaps".

## Seeding

`scripts/legacy-baseline up` gives you, in order:

1. `schema/initial.sql`, loaded by the MariaDB image.
2. Every Doctrine migration, applied by `docker/backend/start.sh`.
3. `tests/bbs/dataset.json` replayed through the REST API by
   `scripts/seed-fixtures`, which is what creates the brands, the vPBX,
   residential and retail companies, the users the scenarios authenticate as
   (`tests/bbs/environment.yaml`), their terminals, DDIs, IVRs, hunt groups,
   conference rooms, conditional routes and the carrier and DDI provider.

The collection had drifted from the API and could not create a brand; the
repairs are in the commit history and were all made against real API responses.
Two fixture values are then pointed at this stack rather than at Irontec's own
BBS runner: the DDI provider addresses and the carrier's SIP proxy. The first
DDI provider address is the tester (inbound calls are only accepted from a
trusted DDI provider address) and the second is proxytrunks itself, because the
carrier loops calls straight back in - which is what the `ddi-bounced` scenarios
exercise.

## Call scenarios

`scripts/call-tests` builds `tests/bbs/Dockerfile` - which compiles pjproject and
`github.com/irontec/bbs` - runs `tests/bbs/entrypoint.sh` inside it on the
compose network, and merges the per-scenario JUnit files into
`results/call-tests/junit.xml`.

`tests/bbs/entrypoint.sh` used to retry each scenario three times and then throw
the exit code away, so a failing scenario was indistinguishable from a passing
one. It still retries - back-to-back SIP scenarios on one node genuinely are
timing-sensitive - but a scenario that only passes on a retry is reported as
`FLAKY` with the attempt number rather than as a clean pass, and the run exits
non-zero if anything failed.

### Baseline result

45 of 48 scenarios pass. Three of those need a retry. The remaining three are
listed in `tests/bbs/known-failures.yaml`: each one passes when run on its own
and fails when run after the scenarios before it, which is scenario-to-scenario
state on a single-node stack rather than a broken feature. They are still run
and still reported.

## Comparing two stacks

`scripts/extract-cdrs` writes one CSV per CDR table - `kam_users_cdrs`,
`kam_trunks_cdrs`, `BillableCalls` - with surrogate keys and absolute timestamps
dropped, so two runs on different infrastructure are comparable.

`scripts/compare-cdrs <baseline> <candidate>` diffs them on call count (total and
per direction), on per-call duration, and on the billing fields (`cost`,
`price`, and the carrier, destination and rating plan each call was billed
against). Calls are matched on who called whom, not on id.

## Known gaps

* **`BillableCalls` is always empty.** It is written by the CGRateS rating chain,
  and neither CGRateS nor the trunks CDR parser is in the stack. Call counts and
  durations can be compared today; billing figures cannot until
  `ivozprovider-cgrates` is added and given a tariff plan.
* **`tests/rest/postman-api-tests.json` predates the JWT API.** It authenticates
  with HTTP Basic against the platform REST endpoint. `./scripts/test-all rest`
  runs it and reports what happens rather than pretending it is green.
* **The portals need `../ivoz-ui`.** `scripts/legacy-baseline up` starts them
  only if that checkout exists next to this one.
