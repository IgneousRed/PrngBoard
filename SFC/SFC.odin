package SFC

import "core:math/bits"

// SFC is a slightly modified SmallFastCounter (https://pracrand.sourceforge.net/)
// The initialization is slightly different.
//
// It would be possible to implement walking backwards.
//
// USE CASE:
// The fastest generator on low-end hardware, that I know of (Please try to prove me wrong).
// NOT CRYPTOGRAPHICALLY SAFE, do not use where predictability is undesirable.
//
// Period:
// Seed dependent, minimal = 2^WordBits, average = 2^(WordBits * 4 - 1)
//
// Peppering:
// Increment can be any odd number. Changing it will result in SFCK.

// -------------------------------- SFC64 --------------------------------

SFC64_init :: proc(seed: u64) -> SFC64 {
	rng := SFC64{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFC64_u64(&rng)
	return rng
}
SFC64_u64 :: proc(r: ^SFC64) -> u64 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 11)
	r[1] = r[2] + (r[2] << 3)
	r[2] = bits.rotate_left64(r[2], 24) + result
	r[3] += 1
	return result
}
SFC64 :: [4]u64

// -------------------------------- SFC32 --------------------------------

SFC32_init :: proc(seed: u32) -> SFC32 {
	rng := SFC32{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFC32_u32(&rng)
	return rng
}
SFC32_u32 :: proc(r: ^SFC32) -> u32 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 9)
	r[1] = r[2] + (r[2] << 3)
	r[2] = bits.rotate_left32(r[2], 21) + result
	r[3] += 1
	return result
}
SFC32 :: [4]u32

// -------------------------------- SFC16 --------------------------------

SFC16_init :: proc(seed: u16) -> SFC16 {
	rng := SFC16{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFC16_u16(&rng)
	return rng
}
SFC16_u16 :: proc(r: ^SFC16) -> u16 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 3)
	r[1] = r[2] + (r[2] << 2)
	r[2] = bits.rotate_left16(r[2], 4) + result
	r[3] += 1
	return result
}
SFC16 :: [4]u16

// -------------------------------- SFC8 --------------------------------

SFC8_init :: proc(seed: u8) -> SFC8 {
	rng := SFC8{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFC8_u8(&rng)
	return rng
}
SFC8_u8 :: proc(r: ^SFC8) -> u8 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 2)
	r[1] = r[2] + (r[2] << 3)
	r[2] = bits.rotate_left8(r[2], 5) + result
	r[3] += 1
	return result
}
SFC8 :: [4]u8

// -------------------------------- InitTest --------------------------------
// Test for ensuring init is random enough

HASH_INIT :: false
HASH_ROUNDS :: 9

InitTest :: u32
InitTest_init :: proc(seed: u8) -> InitTest {return 0}
InitTest_next :: proc(r: ^InitTest) -> u8 {
	defer r^ += 1
	rng: SFC8
	if HASH_INIT {
		rng = [4]u8{u8(r^), u8(r^ >> 8), u8(r^ >> 16), u8(r^ >> 24)}
	} else {
		rng = [4]u8{u8(r^ >> 24), u8(r^ >> 16), u8(r^ >> 8), u8(r^)}
	}
	for _ in 0 ..< HASH_ROUNDS do SFC8_u8(&rng)
	return SFC8_u8(&rng)
}
