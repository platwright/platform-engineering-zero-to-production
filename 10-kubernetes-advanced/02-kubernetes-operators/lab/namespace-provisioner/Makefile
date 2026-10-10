# NamespaceProvisioner operator — developer Makefile.
# Recipe lines are TAB-indented (Make requires tabs).

.PHONY: help fmt vet build run install uninstall sample tidy

help: ## Show this help.
	@echo "Targets: tidy fmt vet build run install uninstall sample"

tidy: ## Download modules and populate go.sum (needs network).
	go mod tidy

fmt: ## Format the Go sources.
	go fmt ./...

vet: ## Run go vet.
	go vet ./...

build: ## Compile the manager binary.
	go build -o bin/manager .

run: ## Run the controller locally against your current kubeconfig context.
	go run .

install: ## Install the Environment CRD into the current cluster.
	kubectl apply -f config/crd/environments.platform.example.com.yaml

uninstall: ## Remove the Environment CRD (deletes all Environments too).
	kubectl delete -f config/crd/environments.platform.example.com.yaml

sample: ## Apply a sample Environment.
	kubectl apply -f config/samples/environment-sample.yaml
