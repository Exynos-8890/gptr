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
