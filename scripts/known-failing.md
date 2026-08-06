# Known failing scenarios

Every `tests/bbs/*test-*.yaml` scenario is executed by `./scripts/call-tests`;
none of them are skipped, disabled or modified. The scenarios below did not
pass on the legacy baseline stack (`./scripts/legacy-baseline up` on a clean
database volume, run of 2026-08-06, artifacts under
`var/baseline/20260806T184410Z/`). Each entry gives the reason the run showed,
not a guess.

## 1010-test-ddi-bounced-int

Alice calls `001999661004` (an international, +1 prefixed number) and the call
has to bounce back into the platform through the trunks proxy.

`kamailio-trunks` classifies it as a rated international call and asks CGRateS
for authorisation before routing it:

```
CHECK-BOUNCE: Call is to one of my inbound DDIs, bounce call
LOAD-GWS (final): [0] Apply to all companies - Pattern USA (prefix: +1) - BBS Carrier (cs5cr5)
ERROR: CGRATES-AUTH-REQUEST: Charging controller unreachable
ERROR: Drop call as CGRateS is down
```

CGRateS (`ivozprovider-cgrates`, config in `cgrates/config/cgrates.json`) is
the rating engine of the platform and is not part of this baseline stack, which
only brings up the components the task lists (kamailio users/trunks, asterisk,
rtpengine). With CGRateS down `kamailio/trunks/config/kamailio.cfg` falls back
to allowing *within-country* calls only (route `IS_WITHIN_COUNTRY`), so every
other scenario passes and only the international one is dropped with a 500.

To cover it, a `cgrates` service has to be added to the proxy side (the Debian
`ivozprovider-profile-proxy` runs it on the same node as `kamailio-trunks`,
which is why `cgrates.json` binds to `trunks.ivozprovider.local:2012/2080`) and
the tariff data has to be loaded for the BBS brand.

## 2405-test-huntgroup-all-complex

## 2415-test-huntgroup-rr-complex

Both scenarios call the "complex" hunt groups (extensions `702` and `703`) and
expect **bob, charlie and dave** to receive the call.

The dataset the scenarios are seeded from, `tests/bbs/dataset.json`, builds
those two hunt groups with different members - alice and an external number:

```
Create HungGroup RingAll Complex          -> extension 702
Add HungGroup RingAll Complex User Alice  -> routeType user,   user alice
Add HungGroup RingAll Complex Number Bob  -> routeType number, numberValue 999661002
Create HungGroup RR Complex               -> extension 703
Add HungGroup RR Complex User Alice       -> routeType user,   user alice
Add HungGroup RR Complex Number Bob       -> routeType number, numberValue 999661002
```

So on a call to `702`/`703` the platform rings alice (who is the caller in the
scenario) and the external number `999661002`, which bounces back to bob. In
the run bob does get the call and answers correctly:

```
>> [bob] Received event INCOMING [0]
+++ [bob] 4/4 steps completed successfully +++
```

but charlie and dave are never called, their sessions time out and the
scenario fails. The scenario expectations and the shipped dataset disagree;
fixing it means changing one of the two, and the scenarios must not be
touched, so this is recorded rather than worked around.
