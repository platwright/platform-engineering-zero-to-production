package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var envCmd = &cobra.Command{
	Use:   "env",
	Short: "Manage environments",
}

var envListCmd = &cobra.Command{
	Use:   "list",
	Short: "List environments",
	RunE: func(cmd *cobra.Command, args []string) error {
		// Real implementation: GET {api_url}/v1/environments and render the result.
		fmt.Println("NAME     BASE   STATUS")
		fmt.Println("dev      -      ready")
		fmt.Println("staging  dev    ready")
		fmt.Println("prod     -      ready")
		return nil
	},
}

var envCreateCmd = &cobra.Command{
	Use:   "create",
	Short: "Create an environment",
	RunE: func(cmd *cobra.Command, args []string) error {
		name, _ := cmd.Flags().GetString("name")
		base, _ := cmd.Flags().GetString("base")
		if name == "" {
			return fmt.Errorf("--name is required")
		}
		// Real implementation: POST {name, base} to the platform API, which provisions
		// the environment (namespace, RBAC, quota) via the resource/delivery planes.
		fmt.Printf("requested environment %q based on %q via %s\n", name, base, apiURL())
		return nil
	},
}

func init() {
	envCreateCmd.Flags().String("name", "", "name of the environment (required)")
	envCreateCmd.Flags().String("base", "dev", "base environment to clone from")

	envCmd.AddCommand(envListCmd)
	envCmd.AddCommand(envCreateCmd)
	rootCmd.AddCommand(envCmd)
}
