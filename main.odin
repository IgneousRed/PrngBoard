package main

import "core:fmt"
import "core:math/rand"
import "core:time"

// FRF64_f64			0.3509521484375
// FRF64_f32			0.4425048828125

// FRF64_32_f64		0.2899169921875
// FRF64_32_f32		0.1220703125

// FRF32_f64			0.2593994140625
// FRF32_f32			0.091552734375

main :: proc() {
	best := ~u64(0)
	sum: u64
	buf: [1 << 16]f64
	// buf: [1 << 16]f32
	for _ in 0 ..< 1 << 16 {
		a := time.time_to_unix_nano(time.now())
		for b in &buf {
			val := FRF64_next(&rng64)
			// val := FRF64_32_next(&rng64)
			// val := FRF32_next(&rng32)

			b = f64(val) / f64(~u64(0))
			// b = f32(val) / f32(~u64(0))
			// b = f64(val) / f64(~u32(0))
			// b = f32(val) / f32(~u32(0))

			// fmt.println(b)
		}
		best = min(best, u64(time.time_to_unix_nano(time.now()) - a))
		for b in buf {sum += u64(b * (1 << 60))}
	}
	fmt.println(f64(best) / (1 << 16), sum)
}

rng64 := u64(0)
FRF64_next :: proc(r: ^u64) -> u64 {
	defer r^ += 0x2d358dccaa6c78a5
	return r^ * (r^ ~ 0x8bb84b93962eacc9)
}
FRF64_32_next :: proc(r: ^u64) -> u32 {
	defer r^ += 0x2d358dccaa6c78a5
	val := u32(r^ >> 32)
	return val * (val ~ 0x53c5ca59)
}

rng32 := u32(0)
FRF32_next :: proc(r: ^u32) -> u32 {
	defer r^ += 0x74743c1b
	return r^ * (r^ ~ 0x53c5ca59)
}

FRF64 :: u64
FRF64_f64 :: proc(r: ^FRF64) -> f64 {
	mix := r^ * (r^ ~ 0x8bb84b93962eacc9)
	r^ += 0x2d358dccaa6c78a5
	return f64(mix) / f64(~u64(0))
}
FRF32 :: u32
FRF32_f32 :: proc(r: ^FRF32) -> f32 {
	mix := r^ * (r^ ~ 0x53c5ca59)
	r^ += 0x74743c1b
	return f32(mix) / f32(~u32(0))
}
