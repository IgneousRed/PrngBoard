package MWC

// Multiply With Carry lag-3
// Only the initialization mixing is my invention.
// Constants are from https://tom-kaitchuck.medium.com/designing-a-new-prng-1c4ffd27124d
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
// None, multiplication is the only mixing constant, but it needs to be carefully chosen.

// -------------------------------- MWC64 --------------------------------

MWC64_init :: proc(seed: u64) -> MWC64 {
	rng := MWC64{0x14057b7ef767814f, 0xcafef00dd15ea5e5, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWC64_u64(&rng)}
	return rng
}
MWC64_u64 :: proc(r: ^MWC64) -> u64 {
	mix := u128(r[1]) * u128(0xfeb344657c0af413) + u128(r[0])
	r^ = {u64(mix >> 64), r[2], r[3], u64(mix)}
	return u64(mix)
}
MWC64 :: [4]u64

// -------------------------------- MWC32 --------------------------------

MWC32_init :: proc(seed: u32) -> MWC32 {
	rng := MWC32{0xd15ea5e5, 0xcafef00d, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWC32_u32(&rng)}
	return rng
}
MWC32_u32 :: proc(r: ^MWC32) -> u32 {
	mix := u64(r[1]) * u64(0xcfdbc53d) + u64(r[0])
	r^ = {u32(mix >> 32), r[2], r[3], u32(mix)}
	return u32(mix)
}
MWC32 :: [4]u32

// -------------------------------- MWC16 --------------------------------
// FOR TESTING ONLY!

MWC16_init :: proc(seed: u16) -> MWC16 {
	rng := MWC16{0x814f, 0xf767, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWC16_u16(&rng)}
	return rng
}
MWC16_u16 :: proc(r: ^MWC16) -> u16 {
	mix := u32(r[1]) * u32(0x9969) + u32(r[0])
	r^ = {u16(mix >> 16), r[2], r[3], u16(mix)}
	return u16(mix)
}
MWC16 :: [4]u16

// -------------------------------- MWC8 --------------------------------
// FOR TESTING ONLY!

MWC8_init :: proc(seed: u8) -> MWC8 {
	rng := MWC8{0x4e, 0x38, seed, seed}
	for _ in 0 ..< 8 {rng[2] ~= MWC8_u8(&rng)}
	return rng
}
MWC8_u8 :: proc(r: ^MWC8) -> u8 {
	mix := u16(r[1]) * u16(0xe4) + u16(r[0])
	r^ = {u8(mix >> 8), r[2], r[3], u8(mix)}
	return u8(mix)
}
MWC8 :: [4]u8

// -------------------------------- InitTest --------------------------------
// Test for ensuring init is random enough

INITTEST_INIT :: false
INITTEST_ROUNDS :: 8

InitTest_init :: proc(seed: u16) -> InitTest {return 0}
InitTest_next :: proc(r: ^InitTest) -> u16 {
	defer r^ += 1
	i := r^
	rng: [4]u16
	if INITTEST_INIT {
		rng[0], i = u16(2 + i % (0x9969 - 2)), i / (0x9969 - 2) // 1 < rng[0] < multiplier
		rng[1], i = u16(1 + i % 65_535), i / 65_535 // 0 < rng[1]
		rng[2], i = u16(i % 65_536), i / 65_536
		rng[3], i = u16(i % 65_536), i / 65_536
	} else {
		rng[3], i = u16(i % 65_536), i / 65_536
		rng[2], i = u16(i % 65_536), i / 65_536
		rng[1], i = u16(1 + i % 65_535), i / 65_535 // 0 < rng[1]
		rng[0], i = u16(2 + i % (0x9969 - 2)), i / (0x9969 - 2) // 1 < rng[0] < multiplier
	}
	for _ in 0 ..< INITTEST_ROUNDS {rng[2] ~= MWC16_u16(&rng)}
	return MWC16_u16(&rng)
}
InitTest :: u64
