# Combined backend coverage report

This folder holds the committed, portable coverage artefacts for the PHP backend.

* `clover.xml` — machine-readable Clover report, produced by
  `library/bin/combine-coverage` from the merged per-suite reports (library
  phpspec + schema ORM + recordings + the four REST Behat suites + REST PHPUnit).
  File paths are repository-relative so the report is diff-able and portable.

The full browsable HTML report (`library/combined-coverage/`) is intentionally
**not** committed: it is ~145 MB across ~2900 files and embeds absolute machine
paths. Regenerate it locally with:

```bash
XDEBUG_MODE=coverage library/bin/combine-coverage   # writes library/combined-coverage/ + this clover.xml
```

## Line coverage (gate, documented exclusions applied)

Measured by `library/bin/coverage-gate` (`composer coverage:gate`, threshold 85%).

| component      | coverage | lines        | 85% |
|----------------|----------|--------------|-----|
| library/Ivoz   | 77.47%   | 9135/11791   | no  |
| platform src   | 86.64%   | 188/217      | yes |
| brand src      | 85.15%   | 413/485      | yes |
| client src     | 85.47%   | 441/516      | yes |
| user src       | 87.09%   | 263/302      | yes |
| combined       | 78.43%   | 10440/13311  | no  |

All four `web/rest/*` components meet the 85% target. `library/Ivoz` (and hence
the combined figure) remain below target; the remaining gap is concentrated in
`Ivoz/**/Domain/Service` and `Domain/Model` concrete classes and is tracked in
[`../coverage-baseline.md`](../coverage-baseline.md), which also lists the
exclusions (infra adapters requiring live CGRateS/Asterisk/Kamailio/RtpEngine/MRF,
in-tree test helpers, the Symfony `Kernel.php`, and the PDF-backed invoice-template
preview action).

> Note: the raw `clover.xml` totals (~76.8%) count the *whole* `library/Ivoz`
> tree without the documented exclusions, so they read slightly lower than the
> gate's per-component figures above.
