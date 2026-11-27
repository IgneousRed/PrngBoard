package main

import "FSR"
import "MWC"
import "MWCP"
import "Odin"
import "SFC"
import "SFCK"
import "WYR"
// import "core:fmt" // Enable with the balanced-prime printing example below.
import "lib"

// Keep the inactive selectors' APIs checked without running a campaign.
#assert(type_of(FSR.FSR64_init) == proc(seed: u64) -> FSR.FSR64)
#assert(type_of(FSR.FSR64_u64) == proc(r: ^FSR.FSR64) -> u64)
#assert(type_of(MWC.MWC64_init) == proc(seed: u64) -> MWC.MWC64)
#assert(type_of(MWC.MWC64_u64) == proc(r: ^MWC.MWC64) -> u64)
#assert(type_of(MWCP.MWCP64_init) == proc(seed: u64) -> MWCP.MWCP64)
#assert(type_of(MWCP.MWCP64_u64) == proc(r: ^MWCP.MWCP64) -> u64)
#assert(type_of(Odin.Odin_init) == proc(seed: u64) -> Odin.Odin)
#assert(type_of(Odin.Odin_u64) == proc(r: ^Odin.Odin) -> u64)
#assert(type_of(SFC.SFC64_init) == proc(seed: u64) -> SFC.SFC64)
#assert(type_of(SFC.SFC64_u64) == proc(r: ^SFC.SFC64) -> u64)
#assert(type_of(SFCK.SFCK64_init) == proc(seed: u64) -> SFCK.SFCK64)
#assert(type_of(SFCK.SFCK64_u64) == proc(r: ^SFCK.SFCK64) -> u64)
#assert(type_of(WYR.WYR64_init) == proc(seed: u64) -> WYR.WYR64)
#assert(type_of(WYR.WYR64_u64) == proc(r: ^WYR.WYR64) -> u64)
#assert(type_of(lib.balanced_prime) == proc(bits: u8) -> u64)

main :: proc() {
	// ---------------- Test Time ----------------
	// lib.test_time(FSR.FSR64_init, FSR.FSR64_u64) // 0.549 ns
	// lib.test_time(MWC.MWC64_init, MWC.MWC64_u64) // 0.565 ns
	// lib.test_time(MWCP.MWCP64_init, MWCP.MWCP64_u64) // 0.610 ns
	// lib.test_time(SFC.SFC64_init, SFC.SFC64_u64) // 0.992 ns
	// lib.test_time(SFCK.SFCK64_init, SFCK.SFCK64_u64) // 0.900 ns
	// lib.test_time(WYR.WYR64_init, WYR.WYR64_u64) // 0.381 ns
	// lib.test_time(Odin.Odin_init, Odin.Odin_u64) // 0.916 ns

	// ---------------- Test Rng ----------------
	// lib.test_rng(FSR.FSR64_init, FSR.FSR64_u64, 0)
	// lib.test_rng(MWC.MWC64_init, MWC.MWC64_u64, 0)
	// lib.test_rng(MWCP.MWCP64_init, MWCP.MWCP64_u64, 0)
	// lib.test_rng(SFC.SFC64_init, SFC.SFC64_u64, 0)
	// lib.test_rng(SFCK.SFCK64_init, SFCK.SFCK64_u64, 0)
	// lib.test_rng(WYR.WYR64_init, WYR.WYR64_u64, 0)
	// lib.test_rng(Odin.Odin_init, Odin.Odin_u64, 2)

	// ---------------- Print Balanced Primes ----------------
	// for _ in 0 ..< 10 {
	// 	fmt.printf("0x%x\n", lib.balanced_prime(64))
	// }
}
