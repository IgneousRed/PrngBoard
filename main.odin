package main

import "FSR"
import "MWC"
import "MWCP"
import "Odin"
import "SFC"
import "SFCK"
import "WYR"
import "core:fmt"
import "lib"

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
