package lib

import "core:intrinsics"

// -------------------------------- Data --------------------------------

// Initial values used in `is_prime()`.
primeArr := [dynamic]uint{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37}

// -------------------------------- Public --------------------------------

// Odin port of WYHash prime finder (https://github.com/wangyi-fudan/wyhash)
// https://en.wikipedia.org/wiki/Miller%E2%80%93Rabin_primality_test
is_prime :: proc(n: u64) -> bool {
	if n == 2 {return true}
	if n % 2 == 0 || n == 1 || !strong_probable_prime(n, 2) {return false}
	if n < 2047 {return true}
	for base in primeArr[1:12] {
		if !strong_probable_prime(n, u64(base)) {return false}
	}
	return true
}

// Finds primes in a sequence, memoizing each.
// Takes a long time if given large `n`.
// Not optimized.
nth_prime :: proc(n: uint) -> uint {
	for i := primeArr[len(primeArr) - 1] + 1; uint(len(primeArr)) <= n; i += 1 {
		isPrime := true
		for p in primeArr {
			if i % p == 0 {
				isPrime = false
				break
			}
		}
		if isPrime {append(&primeArr, i)}
	}
	return primeArr[n]
}

// -------------------------------- Private --------------------------------

@(private)
strong_probable_prime :: proc(n, base: u64) -> bool {
	take := n - 1
	s := intrinsics.count_trailing_zeros(take)
	b := pow_mod(base, take >> s, n)
	if b == 1 || b == take {return true}
	for r: u64 = 1; r < s; r += 1 {
		b = mul_mod(b, b, n)
		if b < 2 {return false}
		if b == take {return true}
	}
	return false
}

@(private)
pow_mod :: proc(a, b, m: u64) -> u64 {
	a, b := a, b
	r: u64 = 1
	for b > 0 {
		if b & 1 > 0 {r = mul_mod(r, a, m)}
		b >>= 1
		if b > 0 {a = mul_mod(a, a, m)}
	}
	return r
}

@(private)
mul_mod :: proc(a, b, m: u64) -> u64 {
	a, b := a, b
	r: u64
	for b > 0 {
		if b & 1 > 0 {r = add_mod(r, a, m)}
		b >>= 1
		if b > 0 {a = add_mod(a, a, m)}
	}
	return r
}

@(private)
add_mod :: proc(a, b, m: u64) -> u64 {
	r := a + b
	if r < a {r -= m}
	return r % m
}
