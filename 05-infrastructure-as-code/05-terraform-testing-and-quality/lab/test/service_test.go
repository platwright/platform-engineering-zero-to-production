package test

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestServiceModule applies the local module for real, asserts on its outputs
// and the file it actually created, then destroys everything. Because the module
// uses only the random + local providers, this test costs nothing and runs in
// seconds — yet exercises the full apply/assert/destroy Terratest pattern you'd
// use against a real GKE module.
func TestServiceModule(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../module",
		Vars: map[string]interface{}{
			"name": "payments",
		},
		NoColor: true,
	}

	// Always clean up, even if an assertion fails.
	defer terraform.Destroy(t, opts)

	// Provision for real.
	terraform.InitAndApply(t, opts)

	// Contract: given name="payments", we get a non-empty config_path that exists
	// and sits under the module's generated/ directory.
	configPath := terraform.Output(t, opts, "config_path")
	require.NotEmpty(t, configPath)
	assert.FileExists(t, configPath)
	assert.True(t, strings.Contains(configPath, "generated/payments.conf"),
		"config should be created under generated/ with the service name")

	// Contract: service_id is populated.
	serviceID := terraform.Output(t, opts, "service_id")
	assert.NotEmpty(t, serviceID)
}
