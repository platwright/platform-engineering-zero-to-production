package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var deployCmd = &cobra.Command{
	Use:   "deploy",
	Short: "Deploy a service version to an environment",
	RunE: func(cmd *cobra.Command, args []string) error {
		app, _ := cmd.Flags().GetString("app")
		version, _ := cmd.Flags().GetString("version")
		if app == "" || version == "" {
			return fmt.Errorf("--app and --version are required")
		}
		// Real implementation: POST a DECLARATIVE deployment request to the platform
		// API, which orchestrates GitOps (ArgoCD) to fulfil it. The CLI does NOT apply
		// manifests itself — that logic lives behind the API.
		fmt.Printf("requested deploy of %s@%s to %s via %s\n", app, version, targetEnv(), apiURL())
		return nil
	},
}

func init() {
	deployCmd.Flags().String("app", "", "application/service name (required)")
	deployCmd.Flags().String("version", "", "image tag or git sha to deploy (required)")
	rootCmd.AddCommand(deployCmd)
}
