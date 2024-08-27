# PRNG Board
This repository contains benchmarks of various Pseudo Random Number Generators.

## PRNGs tested:
- **MWC**
- **MWCP** MWC with output permutation
- **SFC** slightly modified SFC
- **WYR** slightly modified WYRand
- **Odin**

## PRNGs to be tested:
- **SFCK:** SFC but incrementing by k, seems to be slightly worse, but faster (on AArch64).
- **XoShiRo and XoRoShiRo:** Not a fan, will put results at some point.

## Criteria:
- **Randomness:** How random the PRNG appears to be.
- **Predictability:** How hard to predict future PRNG values given X consecutive values (assuming the PRNG used is known).
- **Speed:** How quickly the PRNG produces random numbers.
- **Size:** How much space is required to store the PRNG state.
- **Applicability:** Where the PRNG shines.

## Randomness
Randomness is measured by how many outputs does the testing software need to detect a statistical improbability.
The software used is PractRand (to my knowleadge ammong the best, and at the same time the most pleasent to use).

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

### **MWC**
Not Cryptographicly Safe, probably predictable in 3-4 outputs.

### **MWCP**
Not Cryptographicly Safe, but probably much better than MWC.

### **SFC**
Not Cryptographicly Safe, but probably annoying.

### **WYR**
Not Cryptographicly Safe, probably not trivial.

### **Odin**
Not Cryptographicly Safe, predictable in 1-2 outputs, as it outputs the whole (changable) state.

## Speed
Nanoseconds per Operations.
PRs for other CPUs needed!
At some point I should investigate "prof/spall" from the core library.

### **MWC64:**
- **Mac M2 Pro:** 0.565 ns/op

### **MWCP64:**
- **Mac M2 Pro:** 0.610 ns/op

### **SFC64:**
- **Mac M2 Pro:** 0.992 ns/op

### **WYR64:**
- **Mac M2 Pro:** 0.381 ns/op

### **Odin:**
- **Mac M2 Pro:** 0.916 ns/op

## Size

### **MWC**
WordBytes * 4

### **MWCP**
WordBytes * 4

### **SFC**
WordBytes * 4

### **WYR**
WordBytes

### **Odin**
WordBytes * 2

## Applicability

### **MWC**
Great on modern CPUs, not so much on CPUs with slow multiply. Can have an arbitrary long period. Can't easily be peppered.

### **MWCP**
Great on modern CPUs, not so much on CPUs with slow multiply. Can have an arbitrary long period. Can't easily be peppered.

### **SFC**
Great on all CPUs. It's constant can be peppered.

### **WYR**
Great on modern CPUs, not so much on CPUs with slow multiply. It's 2 constants can be peppered.

### **Odin**
Use something else.

# Contributing
Feel free to ask or report anything.
Also speed tests are currently needed.