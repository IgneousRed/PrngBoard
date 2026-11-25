# Testing guidance

A low statistical score does not prove a PRNG is non-random: even true random
data can consist entirely of zeroes. A high score does not prove randomness
either; a generator may have been lucky, though that can be very unlikely.

Always verify that the pipe contains the intended data and output width, not
buffer addresses or another value. Sending 32-bit values as 64-bit data can
fail immediately; interpreting 64-bit data as 32-bit output can instead improve
the apparent outcome without making the mistake obvious. Take particular care
with non-power-of-two generators and non-byte output widths.

The public helper `lib.test_rng` feeds bytes to `PractRandTest stdin` with
`-tf 2 -te 1 -tlmin 10 -tlmax 99 -multithreaded` and the specified seed. Its
default output width is the generator return type's byte width; an explicit
`outBytes` selects its low bytes. Record the exact tested source, seed, output
width, settings, tool version and results together. Do not assume an older
record's embedded source is identical to today's maintained implementation.

Use [the locked setup](practrand.md) for current tools. Setup checks and bounded
smoke tests do not establish the historical multi-terabyte claims in README.
Historical personal campaign durations are not setup prerequisites or current
runtime estimates. No performance pass/fail threshold is defined by this project.
