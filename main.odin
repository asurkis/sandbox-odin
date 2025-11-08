package main

import "core:fmt"
import "core:io"
import "core:os"

skip_str :: proc(in_stream: io.Reader, str: string) -> (err: io.Error) {
	for c in str {
		ch, _ := io.read_rune(in_stream) or_return
		if c != ch {

		}
	}
	return
}

read_int :: proc(in_stream: io.Reader) -> (result: int, next: rune, err: io.Error) {
	for {
		ch, _ := io.read_rune(in_stream) or_return
		if '0' <= ch && ch <= '9' {
			result = 10 * result + int(ch - '0')
		} else {
			next = ch
			return
		}
	}
}

main :: proc() {
	_enable_raw_mode()
	in_stream := os.stream_from_handle(os.stdin)

	fmt.print("\e[2J\e[1;1H", flush = false)
	fmt.println("Working in terminal")
	fmt.print("\e[999999;999999H\e[6n")

	n_rows, n_cols: int
	next: rune
	io_err := skip_str(in_stream, "\e[")
	assert(io_err == .None)
	n_rows, next, io_err = read_int(in_stream)
	assert(io_err == .None && next == ';')
	n_cols, next, io_err = read_int(in_stream)
	assert(io_err == .None && next == 'R')

	fmt.println("\e[2;1Hwidth:", n_cols, "height:", n_rows)
}

