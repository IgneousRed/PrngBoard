package WYR

import "../lib"

// WYR is a modified WYRand (https://github.com/wangyi-fudan/wyhash)
// Incrementing the state after using it is faster.
//
// I made the init proc sample the state in Phi order.
// Thus to make sure that multiple sequences do not overlap, init them with: [x, x+1, x+2, ...].
//
// It would be trivial to implement walking backwards and skipping steps, but it is rarely used.
//
// USE CASE:
// The fastest general generator that I know of (Please try to prove me wrong).
// Slow on low-end hardware, since it requires upper half of multiplication.
// NOT CRYPTOGRAPHICALLY SAFE, do not use where predictability is undesirable.
//
// Period: 2^WordBits
//
// Peppering:
// You can create your own MIX and INC constants using `balanced_prime()`.

// -------------------------------- WYR64 --------------------------------

WYR64_init :: proc(seed: u64) -> WYR64 {
	return (seed + WYR64_MIX) * WYR64_INC * lib.ODD_PHI_64
}
WYR64_u64 :: proc(r: ^WYR64) -> u64 {
	mix := u128(r^) * u128(r^ ~ WYR64_MIX)
	r^ += WYR64_INC
	return u64(mix >> 64) ~ u64(mix)
}
WYR64 :: u64
WYR64_MIX :: 0x8bb84b93962eacc9
WYR64_INC :: 0x2d358dccaa6c78a5

// -------------------------------- WYR32 --------------------------------

WYR32_init :: proc(seed: u32) -> WYR32 {
	return (seed + WYR32_MIX) * WYR32_INC * lib.ODD_PHI_32
}
WYR32_u32 :: proc(r: ^WYR32) -> u32 {
	mix := u64(r^) * u64(r^ ~ WYR32_MIX)
	r^ += WYR32_INC
	return u32(mix >> 32) ~ u32(mix)
}
WYR32 :: u32
WYR32_MIX :: 0x74743c1b
WYR32_INC :: 0x53c5ca59

// -------------------------------- InitTest --------------------------------
// Test for ensuring init is random enough

InitTest_init :: proc(seed: u32) -> InitTest {return seed}
InitTest_next :: proc(r: ^InitTest) -> u32 {
	defer r^ += 1
	val := (r^ + WYR32_MIX) * WYR32_INC * lib.ODD_PHI_32
	mix := u64(val) * u64(val ~ WYR32_MIX)
	return u32(mix >> 32) ~ u32(mix)
}
InitTest :: u32
