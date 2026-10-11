package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var logsCmd = &cobra.Command{
	Use:   "logs",
	Short: "Stream logs for a service",
	RunE: func(cmd *cobra.Command, args []string) error {
		app, _ := cmd.Flags().GetString("app")
		since, _ := cmd.Flags().GetString("since")
		if app == "" {
			return fmt.Errorf("--app is required")
		}
		// Real implementation: proxy to the platform logging API (Phase 11) and stream
		// the result back to the terminal.
		fmt.Printf("streaming logs for %s in %s (since %s) via %s...\n", app, targetEnv(), since, apiURL())
		return nil
	},
}

func init() {
	logsCmd.Flags().String("app", "", "application/service name (required)")
	logsCmd.Flags().String("since", "1h", "how far back to read logs (e.g. 30m, 1h)")
	rootCmd.AddCommand(logsCmd)
}
