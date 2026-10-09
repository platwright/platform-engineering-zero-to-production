package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// A tiny HTTP server that reports the UID it runs as — handy for proving that a
// hardened container is NOT running as root.
func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintf(w, "ok (uid=%d)\n", os.Getuid())
	})
	log.Printf("listening on :8080 as uid=%d", os.Getuid())
	log.Fatal(http.ListenAndServe(":8080", nil))
}
