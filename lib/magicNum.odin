package lib

import "core:intrinsics"
import "core:time"

// -------------------------------- Data --------------------------------

ODD_PHI_128 :: 0x9e3779b97f4a7c15f39cc0605cedc835
ODD_PHI_64 :: 0x9e3779b97f4a7c15
ODD_PHI_56 :: 0x9e3779b97f4a7d
ODD_PHI_48 :: 0x9e3779b97f4b
ODD_PHI_40 :: 0x9e3779b97f
ODD_PHI_32 :: 0x9e3779b9
ODD_PHI_24 :: 0x9e3779
ODD_PHI_16 :: 0x9e37
ODD_PHI_8 :: 0x9f
ODD_PHI_4 :: 0x9
ODD_PHI_2 :: 0x3

// -------------------------------- Public --------------------------------

// Inspired by WYHash balanced prime finder (https://github.com/wangyi-fudan/wyhash)
// Finds a prime where each byte has equal amount of 0s and 1s.
// Runs roughly 450 times a second when optimized.
balanced_prime :: proc(bits: u8) -> u64 {
	assert(bits > 1 && bits <= 64)

	// Some OSs can only give microsec, so we ignore low bits
	num := u64(time.time_to_unix_nano(time.now())) / 1000

	// Make it odd while saving the most random bit
	num = num << 1 | 1

	// Adding even phi so we only check odd numbers
	for ;; num += ODD_PHI_64 | u64(2) & ~u64(1) {
		if result, ok := is_balanced_prime(num, bits); ok {return result}
	}
}

// -------------------------------- Private --------------------------------

@(private)
is_balanced_prime :: proc(value: u64, bits: u8) -> (result: u64, ok: bool) {
	value, bits := value, bits
	result = value & ((1 << bits) - 1)

	// Check each byte
	for ; bits >= 8; bits -= 8 {
		if intrinsics.count_ones(u8(value)) != 4 {return}
		value >>= 8
	}

	// Check rest of the bits
	if abs(f32(intrinsics.count_ones(u8(value))) - f32(bits) / 2) > 0.5 {return}

	return result, is_prime(result)
}
