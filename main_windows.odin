package main

import "core:c/libc"
import "core:os"
import "core:sys/windows"

@(private = "file")
orig_mode: windows.DWORD

_enable_raw_mode :: proc() {
	stdin := windows.HANDLE(os.stdin)
	ok := windows.GetConsoleMode(stdin, &orig_mode)
	assert(ok == true)
	libc.atexit(_disable_raw_mode)
	raw := orig_mode
	raw &= ~windows.ENABLE_ECHO_INPUT
	raw &= ~windows.ENABLE_LINE_INPUT
	windows.SetConsoleMode(stdin, raw)
}

_disable_raw_mode :: proc "c" () {
	stdin := windows.HANDLE(os.stdin)
	ok := windows.SetConsoleMode(stdin, orig_mode)
}

