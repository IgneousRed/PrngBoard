package SFCK

import "core:math/bits"

// ***TESTS NOT DONE***, but it is similar to SFC.
//
// SFCK is a slightly modified SmallFastCounter (https://pracrand.sourceforge.net/)
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
// Increment can be any odd number. Increment by 1 is SFC.

// -------------------------------- SFCK64 --------------------------------

SFCK64_init :: proc(seed: u64) -> SFCK64 {
	rng := SFCK64{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFCK64_u64(&rng)
	return rng
}
SFCK64_u64 :: proc(r: ^SFCK64) -> u64 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 11)
	r[1] = r[2] + (r[2] << 3)
	r[2] = bits.rotate_left64(r[2], 24) + result
	r[3] += 1
	return result
}
SFCK64 :: [4]u64

// -------------------------------- SFCK32 --------------------------------

SFCK32_init :: proc(seed: u32) -> SFCK32 {
	rng := SFCK32{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFCK32_u32(&rng)
	return rng
}
SFCK32_u32 :: proc(r: ^SFCK32) -> u32 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 9)
	r[1] = r[2] + (r[2] << 3)
	r[2] = bits.rotate_left32(r[2], 21) + result
	r[3] += 1
	return result
}
SFCK32 :: [4]u32

// -------------------------------- SFCK16 --------------------------------

SFCK16_init :: proc(seed: u16) -> SFCK16 {
	rng := SFCK16{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFCK16_u16(&rng)
	return rng
}
SFCK16_u16 :: proc(r: ^SFCK16) -> u16 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 3)
	r[1] = r[2] + (r[2] << 2)
	r[2] = bits.rotate_left16(r[2], 4) + result
	r[3] += 1
	return result
}
SFCK16 :: [4]u16

// -------------------------------- SFCK8 --------------------------------

SFCK8_init :: proc(seed: u8) -> SFCK8 {
	rng := SFCK8{seed, seed, seed, seed}
	for _ in 0 ..< 9 do SFCK8_u8(&rng)
	return rng
}
SFCK8_u8 :: proc(r: ^SFCK8) -> u8 {
	result := r[0] + r[1] + r[3]
	r[0] = r[1] ~ (r[1] >> 2)
	r[1] = r[2] + (r[2] << 3)
	r[2] = bits.rotate_left8(r[2], 5) + result
	r[3] += 1
	return result
}
SFCK8 :: [4]u8

// -------------------------------- InitTest --------------------------------
// Test for ensuring init is random enough

HASH_INIT :: false
HASH_ROUNDS :: 9

InitTest :: u32
InitTest_init :: proc(seed: u8) -> InitTest {return 0}
InitTest_next :: proc(r: ^InitTest) -> u8 {
	defer r^ += 1
	rng: SFCK8
	if HASH_INIT {
		rng = [4]u8{u8(r^), u8(r^ >> 8), u8(r^ >> 16), u8(r^ >> 24)}
	} else {
		rng = [4]u8{u8(r^ >> 24), u8(r^ >> 16), u8(r^ >> 8), u8(r^)}
	}
	for _ in 0 ..< HASH_ROUNDS do SFCK8_u8(&rng)
	return SFCK8_u8(&rng)
}
