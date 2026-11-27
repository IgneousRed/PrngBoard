package main

import "../../FSR"
import "../../MWC"
import "../../MWCP"
import "../../Odin"
import "../../SFC"
import "../../SFCK"
import "../../WYR"
import "../../lib"
import "base:intrinsics"
import "core:fmt"

// Bounded repeatability/state smoke checks, not randomness or performance tests.
smoke :: proc(init: proc(_: $S) -> $R, next: proc(_: ^R) -> $O) {
	seeds := [3]S{0, 1, ~S(0)}
	for seed in seeds {
		left, right := init(seed), init(seed)
		initial := left
		nonzero := false
		for _ in 0 ..< 1000 {
			a, b := next(&left), next(&right)
			assert(a == b)
			nonzero = nonzero || a != 0
		}
		assert(left == right)
		assert(left != initial)
		assert(nonzero)
	}
}

main :: proc() {
	smoke(FSR.FSR8_init, FSR.FSR8_u8)
	smoke(FSR.FSR16_init, FSR.FSR16_u16)
	smoke(FSR.FSR32_init, FSR.FSR32_u32)
	smoke(FSR.FSR64_init, FSR.FSR64_u64)
	smoke(MWC.MWC8_init, MWC.MWC8_u8)
	smoke(MWC.MWC16_init, MWC.MWC16_u16)
	smoke(MWC.MWC32_init, MWC.MWC32_u32)
	smoke(MWC.MWC64_init, MWC.MWC64_u64)
	smoke(MWCP.MWCP8_init, MWCP.MWCP8_u8)
	smoke(MWCP.MWCP16_init, MWCP.MWCP16_u16)
	smoke(MWCP.MWCP32_init, MWCP.MWCP32_u32)
	smoke(MWCP.MWCP64_init, MWCP.MWCP64_u64)
	smoke(SFC.SFC8_init, SFC.SFC8_u8)
	smoke(SFC.SFC16_init, SFC.SFC16_u16)
	smoke(SFC.SFC32_init, SFC.SFC32_u32)
	smoke(SFC.SFC64_init, SFC.SFC64_u64)
	smoke(SFCK.SFCK8_init, SFCK.SFCK8_u8)
	smoke(SFCK.SFCK16_init, SFCK.SFCK16_u16)
	smoke(SFCK.SFCK32_init, SFCK.SFCK32_u32)
	smoke(SFCK.SFCK64_init, SFCK.SFCK64_u64)
	smoke(WYR.WYR32_init, WYR.WYR32_u32)
	smoke(WYR.WYR64_init, WYR.WYR64_u64)
	smoke(Odin.Odin_init, Odin.Odin_u64)

	// Mathematical fixtures, independent of generated PRNG output.
	primes := [15]u64{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 97, 65537}
	for prime in primes {
		assert(lib.is_prime(prime))
	}
	composites := [9]u64{0, 1, 4, 9, 15, 21, 25, 49, 65535}
	for composite in composites {
		assert(!lib.is_prime(composite))
	}
	assert(lib.nth_prime(0) == 2)
	assert(lib.nth_prime(11) == 37)
	assert(lib.nth_prime(12) == 41)
	assert(lib.nth_prime(24) == 97)
	assert(intrinsics.count_ones(u8(0x0f)) == 4)
	assert(intrinsics.count_trailing_zeros(u64(16)) == 4)
	fmt.println("23 generator variants: 3 seeds x 1000 steps; prime/intrinsic checks passed")
}
