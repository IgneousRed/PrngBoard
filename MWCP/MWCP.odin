package MWCP

// Multiply With Carry lag-3 with Permutation
// Inspired by https://tom-kaitchuck.medium.com/designing-a-new-prng-1c4ffd27124d
//
// Compared to Tom's version, I found that just `hi + lo` mix gives many times better rng,
// and there was not that much benefit from additional computation.
// Also it has a much better initialization.
//
// USE CASE:
// The fastest generator with a large period, that I know of (Please try to prove me wrong).
// The period could be arbitrarily large, but 3 words (1 carry) is enough for vast majority of uses.
// Slow on low-end hardware, since it requires upper half of multiplication.
// NOT CRYPTOGRAPHICALLY SAFE, do not use where predictability is undesirable.
//
// Period: Almost 2^(WordBits * 4)
//
// Peppering:
// None, multiplication is the only constant, but it needs to be carefully chosen.

// -------------------------------- MWCP64 --------------------------------

MWCP64_init :: proc(seed: u64) -> MWCP64 {
	rng := MWCP64{0x14057b7ef767814f, 0xcafef00dd15ea5e5, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWCP64_u64(&rng)}
	return rng
}
MWCP64_u64 :: proc(r: ^MWCP64) -> u64 {
	mix := u128(r[1]) * u128(0xfeb344657c0af413) + u128(r[0])
	r^ = {u64(mix >> 64), r[2], r[3], u64(mix)}
	return u64(mix >> 64) + u64(mix)
}
MWCP64 :: [4]u64

// -------------------------------- MWCP32 --------------------------------

MWCP32_init :: proc(seed: u32) -> MWCP32 {
	rng := MWCP32{0xd15ea5e5, 0xcafef00d, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWCP32_u32(&rng)}
	return rng
}
MWCP32_u32 :: proc(r: ^MWCP32) -> u32 {
	mix := u64(r[1]) * u64(0xcfdbc53d) + u64(r[0])
	r^ = {u32(mix >> 32), r[2], r[3], u32(mix)}
	return u32(mix >> 32) + u32(mix)
}
MWCP32 :: [4]u32

// -------------------------------- MWCP16 --------------------------------

MWCP16_init :: proc(seed: u16) -> MWCP16 {
	rng := MWCP16{0x814f, 0xf767, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWCP16_u16(&rng)}
	return rng
}
MWCP16_u16 :: proc(r: ^MWCP16) -> u16 {
	mix := u32(r[1]) * u32(0x9969) + u32(r[0])
	r^ = {u16(mix >> 16), r[2], r[3], u16(mix)}
	return u16(mix >> 16) + u16(mix)
}
MWCP16 :: [4]u16

// -------------------------------- MWCP8 --------------------------------

MWCP8_init :: proc(seed: u8) -> MWCP8 {
	rng := MWCP8{0x4e, 0x38, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWCP8_u8(&rng)}
	return rng
}
MWCP8_u8 :: proc(r: ^MWCP8) -> u8 {
	mix := u16(r[1]) * u16(0xe4) + u16(r[0])
	r^ = {u8(mix >> 8), r[2], r[3], u8(mix)}
	return u8(mix >> 8) + u8(mix)
}
MWCP8 :: [4]u8

// -------------------------------- InitTest --------------------------------
// Test for ensuring init is random enough

INITTEST_INIT :: false
INITTEST_ROUNDS :: 8

InitTest_init :: proc(seed: u8) -> InitTest {return 1}
InitTest_next :: proc(r: ^InitTest) -> u8 {
	i := r^
	r^ += 1
	rng: [4]u8
	if INITTEST_INIT {
		rng[0], i = u8(2 + i % (0xe4 - 2)), i / (0xe4 - 2) // 1 < rng[0] < multiplier
		rng[1], i = u8(1 + i % 255), i / 255 // 0 < rng[1]
		rng[2], i = u8(i % 256), i / 256
		rng[3], i = u8(i % 256), i / 256
	} else {
		rng[3], i = u8(i % 256), i / 256
		rng[2], i = u8(i % 256), i / 256
		rng[1], i = u8(1 + i % 255), i / 255 // 0 < rng[1]
		rng[0], i = u8(2 + i % (0xe4 - 2)), i / (0xe4 - 2) // 1 < rng[0] < multiplier
	}
	for _ in 0 ..< INITTEST_ROUNDS {rng[2] ~= MWCP8_u8(&rng)}
	return MWCP8_u8(&rng)
}
InitTest :: u32
