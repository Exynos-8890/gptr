# Windows CI experiments

Goal: complete Windows release and oldrel-4 CI below 30 minutes, preferably 20,
without dropping existing tests, assertions, native fresh-process isolation or CRAN checks.

Base: upstream `0c4b000` (PR #9 merged). Latest passing baseline run `38993976551`:
release 46m24s, oldrel-4 51m27s; ordinary tests 36--37m, native entries about 3m,
R dependency setup about 1.5m. Command measuring the 30-minute target fails on this baseline.

First sample: eight unchanged ordinary test files. Serial and two-worker arms run the
same eight; two separate serial shard jobs run disjoint four-file halves. Every arm
installs once into a private library, uses installed tests and inherits a two-CPU ceiling.
All testthat workers verify CPU inheritance. Artifact tables retain assertion signatures,
test-file inventories and install/test timing separately. A faster failing or incomplete
arm is not an accepted optimization. These samples do not prove the full target.

Sample run: https://github.com/Exynos-8890/gptr/actions/runs/38999509629
at `cfc666c2cb215b18763fa1e3f89022ee8552d008` (complete; invalid packaging context).
The installed-test directory made `test-aaa-state.R` mistake compiled R code for sources;
serial, parallel and shard2 all failed the same two install assertions. Shard1 passed.
The corrected round stages `tests/` beside `00_pkg_src/gptr/`, matching R CMD check,
without changing any test body. Local partition/layout/comparison regressions: 12 pass.
Latest main release run `38997490469` completed in 33m29s; runner variance means
the paired sample, not a comparison with the slowest historic run, guides the next step.
