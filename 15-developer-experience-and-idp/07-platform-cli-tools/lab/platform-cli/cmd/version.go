package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// version is overridden at build time:
//
//	go build -ldflags "-X github.com/your-org/platform-cli/cmd.version=1.2.3"
var version = "dev"

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the CLI version",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("platform %s\n", version)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
