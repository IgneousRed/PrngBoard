package lib

import "core:c"
import "core:c/libc"
import "core:fmt"
import "core:intrinsics"
import "core:strings"
import "core:time"

foreign import libc_ "system:c"

@(default_calling_convention = "c")
foreign libc_ {
	popen :: proc(command, type: cstring) -> ^libc.FILE ---
	pclose :: proc(f: ^libc.FILE) -> c.int ---
}

// -------------------------------- Public --------------------------------

// Runs an RNG for 1<<16 rounds of 1<<16 runs, reports the results of the fastest.
// Make sure your PC has minimal CPU usage for a minute before you run.
test_time :: proc(init: proc(_: $S) -> $R, next: proc(_: ^R) -> $O) {
	buffer, bestTime, dummy := [1 << 16]u64{}, time.Duration(1) << 62, u64(0)
	rng := init(0)
	for _ in 0 ..< 1 << 16 {
		start := time.now()
		for &b in buffer {b = next(&rng)}
		bestTime = min(time.diff(start, time.now()), bestTime)
		for b in buffer {dummy += b}
	}
	intrinsics.volatile_store(&dummy, dummy)
	fmt.printf("%f ns/op\n", f64(bestTime) / (1 << 16))
}

// Test an RNG with PractRand `-tf 2 -te 1 -multithreaded`.
// This proc should not have performance overhead.
test_rng :: proc(
	init: proc(_: $S) -> $R,
	next: proc(_: ^R) -> $O,
	seed: S,
	outBytes := size_of(O),
) {
	assert(S == u8 || S == u16 || S == u32 || S == u64 || S == u128)
	assert(O == u8 || O == u16 || O == u32 || O == u64 || O == u128)
	assert(outBytes > 0 && outBytes <= size_of(O))
	when ODIN_ENDIAN != .Little {
		fmt.println("WARNING: Your CPU may not be Little-Endian")
		fmt.println("Your test results may not be the same, open a PR and tell me!")
	}

	args := fmt.aprintf(
		"%s 0x%16x\n",
		"PractRandTest stdin -tf 2 -te 1 -tlmin 10 -tlmax 99 -multithreaded -seed",
		seed,
	)
	defer delete(args)
	argsc := strings.clone_to_cstring(args)
	defer delete(argsc)
	f := popen(argsc, "w")

	// Divisible by 1..=16, and less than 1 << 20
	buf := [720_720]u8{}
	rng := init(seed)
	for {
		for out := 0; out < len(buf); out += outBytes {
			val := next(&rng)
			for b := 0; b < outBytes; b += 1 {
				buf[out + b], val = u8(val), val >> 8
			}
		}
		libc.fwrite(&buf, size_of(u8), len(buf), f)
	}
}
