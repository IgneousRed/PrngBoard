package Odin

// -------------------------------- Odin --------------------------------
// The original u64 code is in comments. I had to make a cleaned up version for my OCD.

Odin_init :: proc(seed: u64) -> (rng: Odin) {
	rng.inc = (seed << 1) | 1
	Odin_u64(&rng)
	rng.state += seed
	Odin_u64(&rng)
	return
}
Odin_u64 :: proc(r: ^Odin) -> u64 {
	// old_state := r.state
	// r.state = old_state * 6364136223846793005 + (r.inc | 1)
	// xor_shifted := (((old_state >> 59) + 5) ~ old_state) * 12605985483714917081
	// rot := (old_state >> 59)
	// return (xor_shifted >> rot) | (xor_shifted << ((-rot) & 63))
	hi5 := r.state >> 59
	mix := ((hi5 + 5) ~ r.state) * 12605985483714917081
	r.state = r.state * 6364136223846793005 + (r.inc | 1) // xor here is useless
	return (mix >> hi5) | (mix << (-hi5 & 63))
}
Odin :: struct {
	state: u64,
	inc:   u64,
}
