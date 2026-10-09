# Conftest/OPA policy: enforce an org convention on the Terraform PLAN.
#
# Here the rule is "every local_file must be created under ./generated/". It's a
# deliberately simple stand-in for a real policy such as "every storage bucket
# must be private" or "every resource must carry an owner tag".
#
# Evaluate it with:
#   terraform plan -out=tfplan
#   terraform show -json tfplan > plan.json
#   conftest test plan.json

package main

import rego.v1

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "local_file"
	not startswith(rc.change.after.filename, "./generated/")
	msg := sprintf("%s: files must be created under ./generated/", [rc.address])
}
