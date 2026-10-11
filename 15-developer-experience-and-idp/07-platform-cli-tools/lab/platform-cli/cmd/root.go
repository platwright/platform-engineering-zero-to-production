package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var cfgFile string

var rootCmd = &cobra.Command{
	Use:   "platform",
	Short: "The platform CLI — a thin client of the platform API",
	Long: `platform is the command-line interface to the internal developer platform.

It is a thin client: each command builds a request and calls the platform API.
All orchestration lives behind the API, where the portal and CI reach it too.`,
	SilenceUsage: true,
}

// Execute runs the root command and exits non-zero on error.
func Execute() {
	cobra.CheckErr(rootCmd.Execute())
}

func init() {
	cobra.OnInitialize(initConfig)

	// Persistent flags are available to every subcommand. Config precedence is
	// flag > environment variable > config file > default (resolved by Viper).
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "",
		"config file (default is $HOME/.platform/config.yaml)")
	rootCmd.PersistentFlags().String("env", "", "target environment (overrides config)")
	rootCmd.PersistentFlags().String("api-url", "", "platform API base URL")

	cobra.CheckErr(viper.BindPFlag("default_env", rootCmd.PersistentFlags().Lookup("env")))
	cobra.CheckErr(viper.BindPFlag("api_url", rootCmd.PersistentFlags().Lookup("api-url")))
}

func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		cobra.CheckErr(err)
		viper.AddConfigPath(filepath.Join(home, ".platform"))
		viper.SetConfigType("yaml")
		viper.SetConfigName("config")
	}

	// Environment variables are read as PLATFORM_<KEY>, e.g. PLATFORM_DEFAULT_ENV.
	viper.SetEnvPrefix("platform")
	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err == nil {
		fmt.Fprintln(os.Stderr, "using config file:", viper.ConfigFileUsed())
	}
}

// apiURL returns the configured platform API base URL (or a hint if unset).
func apiURL() string {
	if url := viper.GetString("api_url"); url != "" {
		return url
	}
	return "(api_url not set; see ~/.platform/config.yaml)"
}

// targetEnv resolves the environment from flag/env/config, defaulting to dev.
func targetEnv() string {
	if env := viper.GetString("default_env"); env != "" {
		return env
	}
	return "dev"
}
