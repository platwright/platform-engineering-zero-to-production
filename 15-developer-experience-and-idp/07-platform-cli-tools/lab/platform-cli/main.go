// Command platform is a thin CLI client of the internal developer platform API.
//
// It wraps API calls, not business logic: each subcommand builds a request and calls
// the platform API, where orchestration lives (so the portal and CI reuse it too).
package main

import "github.com/your-org/platform-cli/cmd"

func main() {
	cmd.Execute()
}
