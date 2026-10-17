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

Corrected sample: https://github.com/Exynos-8890/gptr/actions/runs/39000057544
at `8a3b59c` (complete). Serial and shard-union signatures match exactly:
2773 pass, 0 failures, 16 skips. Test times: serial 305.18s; shards 173.23s and
148.99s. Parallel2 took 272.63s but failed one unchanged HTTP timing assertion;
it is rejected, not counted as a speedup. Different hosted runners add measurement noise.
Full original checks: https://github.com/Exynos-8890/gptr/actions/runs/39000168147
at `b9d95a4`. Release passed in 31m54s (31766 ordinary + 1906 native passes,
107 + 1 skips, Status OK); oldrel-4 remained live past 30m. Thus two workers alone
miss the time target even though release preserves the original assertion counts.
No package test entry or assertion changes;
the standard check action, native fresh entries, warning/status gates are retained.
The full probe uses two testthat file workers and one math thread on normal Windows
runner allocation, like main's Linux parallel gate; unlike the sample it does not impose
an OS-wide affinity ceiling. The real serial CRAN-mode job remains unchanged on main.

Isolated worktree: `/private/tmp/gptr-windows-ci.PVo7GN/repo`, branch
`perf/windows-ci-experiments`; user main worktree and notes remain untouched.
Native/full target is unproven until both complete Windows versions pass below 30m.

Round 1 probe: four serial R CMD check jobs per Windows R version. Each retains all ten
original native fresh-process entries and checks one disjoint quarter of the 190 ordinary
files. The union covers all 200 files; CRAN/default entry paths never opt into sharding.
Selection/config regressions: 15 pass (partition, default, ordering, malformed selectors
and valid Actions context scope).
Successful entries retain scalar assertion results and observed file inventories for a
cross-job coverage audit. No test body, timeout or assertion is relaxed.

Serial-shard run: https://github.com/Exynos-8890/gptr/actions/runs/39001048332
at `3004305` (running; all eight Windows jobs admitted). The preceding `39000992551`
failed workflow validation before starting jobs; runner.temp belongs in step env, not
job env. Regression added before fixing it. Result audit regressions: 10 pass; missing,
duplicate, foreign-source, failing and empty-native outputs are rejected.

Audit completed artifacts with:
`Rscript --vanilla dev/ci/windows-perf/audit-shards.R ARTIFACT_ROOT SOURCE_SHA`.
Original successful `38993976551` outputs have 31766 ordinary passes / 107 skips and
1906 native passes / 1 skip on each Windows R version. Compare counts as well as inventory.
Latest untouched main oldrel-4 run `38997490469` failed in its disk-observer fixture
(`observer-metadata-invalid`); that serial failure predates these experiments and is not
evidence that sharding caused a regression. Failing jobs still invalidate an experiment.

Upstream active ruleset `24955100` requires `windows-latest (release)` and
`windows-latest (oldrel-4)`. A production shard rollout must preserve those contexts as
aggregate gates, requiring every shard and its coverage audit; renaming or satisfying
them with just one quarter would weaken protection. Do not edit the ruleset.

Round 1 shard release1/4 failed in the original native disk-observer 1s snapshot
deadline; release4/4 also failed its observer, while oldrel1/4 passed in about 16m.
Ordinary release1/4 passed all 7741 assertions / 38 skips. Native duplication adds
unnecessary work and repeated opportunities for the pre-existing guard flake.
Round 2 assigns all ten unchanged native bodies to shard1 only, still in ten fresh
entry processes. Other groups retain their ordinary partitions. The aggregate audit
requires every native output once and every ordinary file once (18 selection/config
and 12 audit regression assertions pass). No observer deadline or guard is changed.

Rtools A/B: https://github.com/Exynos-8890/gptr/actions/runs/39001842418
at `776e622` (running). Both oldrel jobs run the same source-install regression file;
only setup-r's extra Rtools installation differs. No production Rtools change yet.

Round 2 full run: https://github.com/Exynos-8890/gptr/actions/runs/39002125559
at `bb38895` (running; all eight jobs started). Native cases run only in group1;
other groups' native entry processes are empty by explicit CI partition, not CRAN skip.
The audit verifies real native pass output in group1 and no duplicated native execution
elsewhere. Ordinary + native coverage must still equal all 200 files.

No-extra-Rtools warm sample passed: 18s R setup, 46.14s source install, 46.37s tests,
42 passes, 0 failures/warnings/skips. Standard Rtools arm still running. Before adopting
this option, verify cold dependency setup and a full check, not just warm installation.
Cold probe: https://github.com/Exynos-8890/gptr/actions/runs/39002216479 at `58dc301`.

Completed comparisons: both versions' first-round shard unions match all 190 ordinary
files, 31766 passes / 107 skips / no failures or warnings. The full run is still rejected
because of native observer failures. Native2 oldrel also failed two background-shell
timing assertions, so file workers are not the production choice.

First Rtools default arm failed before tests in Rtools42 Bash (`object 'testthat' not
found` for an Rscript expression); corrected probe uses PowerShell for that expression.
Corrected A/B `39002386734` at `26d6a38`: both pass the same 42 assertions. R setup
170s -> 20s; whole jobs 6m07s -> 3m56s. Cold no-extra-Rtools probe also passed all 42.

Clean candidate: branch `perf/windows-ci`, commit `c07fcf4`, separate worktree
`/private/tmp/gptr-windows-ci.PVo7GN/production`. Local gate regressions: 45 pass;
native bodies and warning handlers are AST-identical to main, runtime R/ unchanged.
Validation-only commit `77e3a14` differs solely by a caller workflow, invokes the exact
production workflow and the unchanged serial Linux CRAN-mode job. Run:
https://github.com/Exynos-8890/gptr/actions/runs/39002733279 (live; no time-target claim yet).
