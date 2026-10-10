package main

import (
	"fmt"
	"net/http"
	"os"
)

// A deliberately tiny service: it builds to a small static binary, so the image
// is quick to scan and has a minimal attack surface (Module 02.5). The point of
// this lab is the pipeline around it — build, scan, sign, promote — not the app.
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "ok (uid=%d)\n", os.Getuid())
	})
	_ = http.ListenAndServe(":8080", nil)
}
