package FSR

import "../lib"
import "core:math/bits"

// FSR (FastSwapRotate) version 1
// Requires more testing.
//
// It would be possible to implement walking backwards.
//
// USE CASE:
// The fastest generator for med-high CPUs without multiplication (Please try to prove me wrong).
// NOT CRYPTOGRAPHICALLY SAFE, do not use where predictability is undesirable.
//
// Period:
// Seed dependent, minimal = 2^WordBits, average = 2^(WordBits * 5 - 1)
//
// Peppering:
// Increment can be any odd number.
//
// Speed:
// M2  0.549 ns
// x86 0.562 ns

// -------------------------------- FSR64 --------------------------------

FSR64_init :: proc(seed: u64) -> FSR64 {
	rng := FSR64{seed, seed, seed, seed, seed}
	for _ in 0 ..< 15 do FSR64_u64(&rng)
	return rng
}
FSR64_u64 :: proc(r: ^FSR64) -> u64 {
	t := r[0] - r[1]
	r[0] = r[1] + r[4]
	r[1] = bits.byte_swap(r[2])
	r[2] = r[3] + t
	r[3] = bits.rotate_left64(t, 15)
	r[4] += lib.ODD_PHI_64
	return r[0]
}
FSR64 :: [5]u64

// -------------------------------- FSR32 --------------------------------

FSR32_init :: proc(seed: u32) -> FSR32 {
	rng := FSR32{seed, seed, seed, seed, seed}
	for _ in 0 ..< 15 do FSR32_u32(&rng)
	return rng
}
FSR32_u32 :: proc(r: ^FSR32) -> u32 {
	t := r[0] - r[1]
	r[0] = r[1] + r[4]
	r[1] = bits.byte_swap(r[2])
	r[2] = r[3] + t
	r[3] = bits.rotate_left32(t, 21)
	r[4] += lib.ODD_PHI_32
	return r[0]
}
FSR32 :: [5]u32

// -------------------------------- TESTING_ONLY --------------------------------

FSR16_init :: proc(seed: u16) -> FSR16 {
	rng := FSR16{seed, seed, seed, seed, seed}
	for _ in 0 ..< 15 do FSR16_u16(&rng)
	return rng
}
FSR16_u16 :: proc(r: ^FSR16) -> u16 {
	t := r[0] - r[1]
	r[0] = r[1] + r[4]
	r[1] = swap16(r[2])
	r[2] = r[3] + t
	r[3] = bits.rotate_left16(t, 5)
	r[4] += lib.ODD_PHI_16
	return r[0]
}
FSR16 :: [5]u16
swap16 :: proc(v: u16) -> u16 {
	return(
		((v & 0xF000) >> 12) |
		((v & 0x0F00) >> 04) |
		((v & 0x00F0) << 04) |
		((v & 0x000F) << 12) \
	)
}

FSR8_init :: proc(seed: u8) -> FSR8 {
	rng := FSR8{seed, seed, seed, seed, seed}
	for _ in 0 ..< 15 do FSR8_u8(&rng)
	return rng
}
FSR8_u8 :: proc(r: ^FSR8) -> u8 {
	t := r[0] - r[1]
	r[0] = r[1] + r[4]
	r[1] = swap8(r[2])
	r[2] = r[3] + t
	r[3] = bits.rotate_left8(t, 5)
	r[4] += lib.ODD_PHI_8
	return r[0]
}
FSR8 :: [5]u8
swap8 :: proc(v: u8) -> u8 {
	return ((v & 0xC0) >> 6) | ((v & 0x30) >> 2) | ((v & 0x0C) << 2) | ((v & 0x03) << 6)
}

// -------------------------------- InitTest --------------------------------
// Test for ensuring init is random enough

HASH_INIT :: true
HASH_ROUNDS :: 15

InitTest :: u64
InitTest_init :: proc(seed: u8) -> InitTest {return 0}
InitTest_next :: proc(r: ^InitTest) -> u8 {
	defer r^ += 1
	rng: FSR8
	if HASH_INIT {
		rng = [5]u8{u8(r^), u8(r^ >> 8), u8(r^ >> 16), u8(r^ >> 24), u8(r^ >> 32)}
	} else {
		rng = [5]u8{u8(r^ >> 32), u8(r^ >> 24), u8(r^ >> 16), u8(r^ >> 8), u8(r^)}
	}
	for _ in 0 ..< HASH_ROUNDS do FSR8_u8(&rng)
	return FSR8_u8(&rng)
}
