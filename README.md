# PRNG Board
This repository contains benchmarks of various Pseudo Random Number Generators.

## PRNGs tested
- **FSR**
- **MWC**
- **MWCP** MWC with output permutation
- **SFC**
- **SFCK** slightly modified SFC
- **WYR** slightly modified WYRand
- **Odin** based on PCG (could not find exact PCG)

## Criteria
- **Randomness:** How random the PRNG appears to be.
- **Predictability:** How hard to predict future PRNG values given X consecutive values (assuming the PRNG used is known).
- **Speed:** How quickly the PRNG produces random numbers.
- **Size:** How much space is required to store the PRNG state.
- **Applicability:** Where the PRNG shines.

## Historical results and interpretation

The comparison figures below summarize historical runs, not current verification.
The statistical records used PractRand 0.95 (expanded test set, extra folding);
timing figures were recorded on a Mac M2 Pro. The original compiler version and
complete run environment were not recorded here. Per-run source variants and
observations are maintained separately; this public summary is not a full
reproduction dataset. The results have not been rerun with the current locked
Odin/PractRand 0.96 environment. Predictability and applicability statements are
the author’s historical assessments, not cryptographic validation.

## Randomness
Randomness is measured by how many outputs does the testing software need to detect a statistical improbability.
The software used is PractRand (to my knowleadge ammong the best, and at the same time the most pleasent to use).
Used PractRand settings are Extended + Max Fold (the most rigorous)

### **FSR:**
Probably scales worse than liniarly
- **40bit state, 8bit output:** 2^35 bytes
- **80bit state, 16bit output:** 2^44 bytes
- **160bit state, 32bit output:** >2^45 bytes
- **320bit state, 64bit output:** >2^45 bytes

### **MWC:**
Probably scales liniarly
- **32bit state, 8bit output:** 2^16 bytes
- **64bit state, 16bit output:** 2^30 bytes
- **128bit state, 32bit output:** >2^45 bytes
- **256bit state, 64bit output:** >2^45 bytes

### **MWCP:**
Probably scales liniarly
- **32bit state, 8bit output:** 2^27 bytes
- **64bit state, 16bit output:** >2^45 bytes (but probably close)
- **128bit state, 32bit output:** >2^45 bytes
- **256bit state, 64bit output:** >2^45 bytes

### **SFC:**
Probably scales worse than liniarly
- **32bit state, 8bit output:** 2^28 bytes
- **64bit state, 16bit output:** >2^45 bytes
- **128bit state, 32bit output:** >2^45 bytes
- **256bit state, 64bit output:** >2^45 bytes

### **SFCK:**
Probably scales worse than liniarly
- **32bit state, 8bit output:** 2^28 bytes
- **64bit state, 16bit output:** >2^45 bytes
- **128bit state, 32bit output:** >2^45 bytes
- **256bit state, 64bit output:** >2^45 bytes

### **WYR:**
Probably scales liniarly
- **32bit state, 32bit output:** 2^26 bytes
- **64bit state, 64bit output:** 2^45 bytes

### **Odin:**
Probably scales liniarly
- **128bit state, 64bit output:** 2^19 bytes

## Predictability
I am not into Cryptography, so I can only guess.
PRs VERY much welcome.

### **FSR**
Not Cryptographicly Safe, but probably annoying.

### **MWC**
Not Cryptographicly Safe, probably predictable in 3-4 outputs.

### **MWCP**
Not Cryptographicly Safe, but probably much better than MWC.

### **SFC**
Not Cryptographicly Safe, but probably annoying.

### **SFCK**
Not Cryptographicly Safe, but probably annoying.

### **WYR**
Not Cryptographicly Safe, probably not trivial.

### **Odin**
Not Cryptographicly Safe, predictable in 1-2 outputs, as it outputs the whole (changable) state.

## Speed
Nanoseconds per Operations.
PRs for other CPUs needed!
At some point I should investigate "prof/spall" from the core library.

### **FSR64:**
- **Mac M2 Pro:** 0.549 ns/op

### **MWC64:**
- **Mac M2 Pro:** 0.565 ns/op

### **MWCP64:**
- **Mac M2 Pro:** 0.610 ns/op

### **SFC64:**
- **Mac M2 Pro:** 0.992 ns/op

### **SFCK64:**
- **Mac M2 Pro:** 0.900 ns/op

### **WYR64:**
- **Mac M2 Pro:** 0.381 ns/op

### **Odin:**
- **Mac M2 Pro:** 0.916 ns/op

## Size

### **FSR**
WordBytes * 5

### **MWC**
WordBytes * 4

### **MWCP**
WordBytes * 4

### **SFC**
WordBytes * 4

### **SFCK**
WordBytes * 4

### **WYR**
WordBytes

### **Odin**
WordBytes * 2

## Applicability

### **FSR**
Great on desktop CPUs. Its constant can be peppered.

### **MWC**
Great on modern CPUs, not so much on CPUs with slow multiply. Can have an arbitrary long period. Can't easily be peppered.

### **MWCP**
Great on modern CPUs, not so much on CPUs with slow multiply. Can have an arbitrary long period. Can't easily be peppered.

### **SFC**
Great on all CPUs. Its constant can be peppered.

### **SFCK**
Great on all CPUs. Its constant can be peppered.

### **WYR**
Great on modern CPUs, not so much on CPUs with slow multiply. Its 2 constants can be peppered.

### **Odin**
Use something else.

# Contributing
Feel free to ask or report anything.
Also speed tests are currently needed.

## Development setup

[Nix](https://nix.dev/install-nix.html) is required. The tracked flake and lock select
the toolchain; no sibling checkout or populated cache is required.

```sh
./scripts/dev odin version
mkdir -p .work/build
./scripts/dev odin build . -thread-count:1 -debug -out:.work/build/prng-board
```

Enable the pre-commit check once per clone with `git config core.hooksPath .githooks`, or run `./scripts/check-deps` before every commit. It reports available dependency
updates without changing the lock. Run builds from this directory; the launcher
keeps its generated environment under ignored `.work/` and works from source
archives as well as Git checkouts. Existing experiment data is not setup input.

Apple Silicon macOS 26 or newer uses the shared LLVM 23.1.6 toolchain and
Python 3.15.2. Linux retains its locked toolchain and requires separate runtime
verification.

The shared environment also supplies PractRand 0.96 as `PractRandTest`, used by
statistical invocations in the public harness. See [PractRand setup](docs/practrand.md)
and [testing guidance](docs/testing.md). Run generated programs through
`./scripts/dev` so the pinned executable is on PATH. The default harness exits
without starting a timing or statistical campaign; uncomment only the invocation
you intend to run.

The public source, documentation and setup do not require private or local state.
Reserved folders and private working instructions (`AGENTS.md` at any depth) are
excluded from Git publication, source staging and archives.
Before committing, enable the hook above or run
`./scripts/dev python3 scripts/check-publication.py` against the staged tree.
New root paths require publication review. Maintained generator implementations,
`lib/`, the benchmark entrypoint, setup, general documentation and
`LanguageDefaultPrng.txt` are public. Private experiments and planning are not
public setup inputs; machine-only evidence and recovery must never be uploaded.

When records become private or local-only, their more-visible history must also
be sanitized; a deletion at HEAD is insufficient. Run the publication check with
`--history --ref refs/heads/main` before pushing, and do not merge old
pre-migration ancestry back in. Only the explicit `main` ref is approved for
upload; app-owned recovery refs and backup refs stay machine-only. Never use a
mirror push. Local app recovery is outside the publication task and remains
untouched; no app shutdown or checkpoint maintenance is required.
History replacement changes commit identities: update pins through their owners
rather than assuming old SHAs remain supported. Hosted caches and other clones
are outside the guarantees of an owned-ref rewrite.

Debug builds and bounded startup have been verified on Apple Silicon macOS 27.2.1.
The public harness passes the maximal warnings-as-errors check. The former
`core:intrinsics` imports now use the compiler's `base:intrinsics` path; procedure
bodies are unchanged. Compile-time selector API checks keep the default harness
idle without unused imports. Enable the commented `core:fmt` import as well when
selecting the balanced-prime printing example.

See [dependency provenance and compatibility](docs/dependencies.md) and the
[bounded smoke checks](docs/testing.md#bounded-setup-and-functional-checks).
Linux runtime verification remains TODO; setup checks do not establish fresh
statistical or performance measurements.
