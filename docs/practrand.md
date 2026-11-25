# PractRand setup

Nix and the checked-in lock provide PractRand 0.96 as `PractRandTest`; no separate
installation or manual PATH change is needed. From the repository root:

```sh
./scripts/dev PractRandTest --self_test
mkdir -p .work/build
./scripts/dev odin build . -thread-count:1 -debug -out:.work/build/prng-board
./scripts/dev .work/build/prng-board
```

The public `main.odin` is a selectable benchmark harness: all timing/statistical
invocations are commented out by default, so its default execution exits without
running a campaign. Select the desired invocation deliberately. Statistical
invocations in `lib.test_rng` are unbounded for ordinary smoke-test purposes;
do not enable them just to verify setup.

The recipe in `nix/practrand.nix` builds pinned upstream PractRand 0.96 with
self-tests enabled. On ARM it uses the standard chrono clock instead of x86
clock intrinsics; statistical algorithms are unchanged. It builds only the RNG
test tool. Linux runtime verification remains separate from Apple Silicon setup.

Historical comparison results were recorded with PractRand 0.95. Availability or
self-testing of 0.96 does not reproduce or update those results. See
[testing guidance](testing.md) before running a new campaign. Remove generated
executables and debug bundles after use; keep any new authoritative results in
their approved maintained location rather than `.work/`.
