package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

// serviceName is rendered by the Backstage scaffolder from the developer's input.
// It is a plain string, so this file stays valid, gofmt-clean Go in the template.
const serviceName = "${{ values.name }}"

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintf(w, "hello from %s\n", serviceName)
	})

	// Liveness/readiness endpoint used by the Helm chart's probes.
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})

	addr := ":8080"
	log.Printf("%s listening on %s (uid=%d)", serviceName, addr, os.Getuid())
	log.Fatal(http.ListenAndServe(addr, mux))
}
