package main

import (
	"fmt"
	"runtime"
)

// Prints the OS/architecture it was compiled for — so you can see which variant of
// a multi-architecture image actually ran on your machine.
func main() {
	fmt.Printf("hello from %s/%s\n", runtime.GOOS, runtime.GOARCH)
}
