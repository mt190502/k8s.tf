## ============================================================================================= ##
#  K8S.TF Makefile                                                                                #
#                                                                                                 #
#  Authors:                                                                                       #
#    - Taha <mt190502@mtaha.dev>										                          #
#                                                                                                 #
#  Special thanks to:                                                                             #
#    - Kreato <hi@krea.to>                                                                        #
#    - Siderolabs Talos Contributors                                                              #
#                                                                                                 #
#  Copyright (c) 2026 Taha. All rights reserved.                                                  #
#  Licensed under the AGPL License. See LICENSE in the project root for license information.      #
## ============================================================================================= ##
.PHONY: default generate plan apply destroy clean decrypt encrypt build infra-plan infra-apply infra-destroy manifests-plan manifests-apply manifests-destroy _check_values
.SILENT:

## --------------------------------------------------------------------------------------------- ##
#  Environments 																			      #
## --------------------------------------------------------------------------------------------- ##
#~ Default environment is 'prod', but you can specify 'dev' or others as needed.
ENV ?= prod
TARGET ?= all

##~ ---------------------------------------------------------------------------- ~##
#  Provider plugin cache — shared across all units so tofu init only downloads    #
#  each provider binary once. Works as a fallback alongside Terragrunt's built-in  #
#  provider_cache_server.                                                          #
##~ ---------------------------------------------------------------------------- ~##
PROVIDER_CACHE_DIR ?= $(HOME)/.cache/terragrunt/providers
export TF_PLUGIN_CACHE_DIR = $(PROVIDER_CACHE_DIR)

##~ ---------------------------------------------------------------------------- ~##
#  Secrets — stack files read this via read_terragrunt_config()                   #
#                                                                                  #
#  Override:                                                                       #
#    make infra-plan SECRETS=/path/to/other.hcl                                    #
##~ ---------------------------------------------------------------------------- ~##
SECRETS ?= $(PWD)/secrets.hcl
export TERRAGRUNT_SECRETS = $(SECRETS)

##~ ---------------------------------------------------------------------------- ~##
#  Manifests target selector                                                       #
#  TARGET can be: all (default), apps, infra (core), or settings                   #
##~ ---------------------------------------------------------------------------- ~##
ifeq ($(TARGET),apps)
  MANIFESTS_WORK_DIR = $(STACK_DIR)/manifests/.terragrunt-stack/apps
else ifeq ($(TARGET),infra)
  MANIFESTS_WORK_DIR = $(STACK_DIR)/manifests/.terragrunt-stack/core
else ifeq ($(TARGET),settings)
  MANIFESTS_WORK_DIR = $(STACK_DIR)/manifests/.terragrunt-stack/settings
else
  MANIFESTS_WORK_DIR = $(STACK_DIR)/manifests/.terragrunt-stack
endif

##~ ---------------------------------------------------------------------------- ~##
#  Stack targets                                                                   #
##~ ---------------------------------------------------------------------------- ~##
export STACK_ENV = $(ENV)
STACK_FILE = $(ENV).stack.hcl
STACK_DIR  = .terragrunt-stack
VALUES_FILE = $(ENV).values.hcl
TG_RUN_ALL = terragrunt --working-dir "$(STACK_DIR)" run --all
TG_RUN_INFRA = terragrunt --working-dir "$(STACK_DIR)/infra/.terragrunt-stack" run --all
TG_RUN_MANIFESTS = terragrunt --working-dir "$(MANIFESTS_WORK_DIR)" run --all
STACK_NESTED_DIRS = $(STACK_DIR)/.terragrunt-stack $(STACK_DIR)/*/.terragrunt-stack $(STACK_DIR)/*/*/.terragrunt-stack
STACK_DEEP_NESTED_DIRS = $(STACK_DIR)/.terragrunt-stack $(STACK_DIR)/*/*/.terragrunt-stack
KUBE_CONTEXT ?= admin@$(shell awk -F'"' '/^[[:space:]]*cluster_name[[:space:]]*=/{print $$2; exit}' $(ENV).values.hcl)

##~ ---------------------------------------------------------------------------- ~##
#  Mock mode check --- prevents apply/destroy when using mock values               #
##~ ---------------------------------------------------------------------------- ~##
_check_values:
	@if ! grep -qE '^\s*infra\s*=\s*\{' $(VALUES_FILE); then \
		echo ""; \
		echo "╔══════════════════════════════════════════════════════════════════╗"; \
		echo "║  ERROR: Mock mode detected                                       ║"; \
		echo "║                                                                  ║"; \
		echo "║  Cannot run apply/destroy with mock values.                      ║"; \
		echo "║  Please configure $(VALUES_FILE) with real infrastructure.       ║"; \
		echo "╚══════════════════════════════════════════════════════════════════╝"; \
		echo ""; \
		exit 1; \
	fi



## --------------------------------------------------------------------------------------------- ##
#  Helpers                                                                                        #
## --------------------------------------------------------------------------------------------- ##
##~ ---------------------------------------------------------------------------- ~##
#  SOPS encryption/decryption helper target. Expects the following environment     #
#  variables to be set:                                                            #
#    - SOPS_AGE_KEY_FILE: Path to the AGE key file used for encryption/decryption. #
#    - TARGET_FILE: Path to the file to encrypt or decrypt.						   #
#    - MODE: Either 'encrypt' or 'decrypt' to specify the operation.               #
##~ ---------------------------------------------------------------------------- ~##
_sops:
	set -euo pipefail; \
	: "$${SOPS_AGE_KEY_FILE:?SOPS_AGE_KEY_FILE is not set}"; \
	: "$${TARGET_FILE:?TARGET_FILE is not set}"; \
	: "$${MODE:?MODE is not set}"; \
	[ -f "$$SOPS_AGE_KEY_FILE" ] || { echo "Error: SOPS_AGE_KEY_FILE does not exist at $$SOPS_AGE_KEY_FILE"; exit 1; }; \
	[ -f "$$TARGET_FILE" ]       || { echo "Error: TARGET_FILE does not exist at $$TARGET_FILE"; exit 1; }; \
	if [ "$$MODE" = "decrypt" ]; then \
		grep -q 'BEGIN AGE ENCRYPTED FILE' "$$TARGET_FILE" || { echo "Error: TARGET_FILE does not appear to be a valid SOPS file or is already decrypted"; exit 0; }; \
		sops -i -d "$$TARGET_FILE"; \
		echo "Decrypted $$TARGET_FILE using SOPS."; \
	elif [ "$$MODE" = "encrypt" ]; then \
		grep -q 'BEGIN AGE ENCRYPTED FILE' "$$TARGET_FILE" && { echo "Error: TARGET_FILE appears to already be encrypted"; exit 1; }; \
		sops -i -e "$$TARGET_FILE"; \
		echo "Encrypted $$TARGET_FILE using SOPS."; \
	else \
		echo "Error: MODE must be either 'decrypt' or 'encrypt'"; \
		exit 1; \
	fi

decrypt:
	for file in $$(find . -type f \( -name "secrets.hcl" -o -name "secret.hcl" \) ! -name "*.example"); do \
		$(MAKE) _sops MODE=decrypt TARGET_FILE="$$file"; \
	done

encrypt:
	for file in $$(find . -type f \( -name "secrets.hcl" -o -name "secret.hcl" \) ! -name "*.example"); do \
		$(MAKE) _sops MODE=encrypt TARGET_FILE="$$file"; \
	done


##~ ---------------------------------------------------------------------------- ~##
#  Default target: shows usage info. You can also run 'make help' for the same.    #
##~ ---------------------------------------------------------------------------- ~##
default:
	echo "Available targets:"
	echo " stack:"
	echo "   generate           - Generate Terragrunt stack units              (ENV=prod|dev, default: prod)"
	echo " infra:"
	echo "   infra-plan         - Plan infra units only                        (ENV=prod|dev, SECRETS=path.hcl)"
	echo "   infra-apply        - Apply infra units only                       (ENV=prod|dev, SECRETS=path.hcl)"
	echo "   infra-destroy      - DANGER: Destroy infra units only             (ENV=prod|dev, SECRETS=path.hcl)"
	echo " manifests:"
	echo "   manifests-plan     - Plan manifest units                          (ENV=prod|dev, SECRETS=path.hcl, TARGET=all|apps|infra|settings)"
	echo "   manifests-apply    - Apply manifest units                         (ENV=prod|dev, SECRETS=path.hcl, TARGET=all|apps|infra|settings)"
	echo "   manifests-destroy  - DANGER: Destroy manifest units               (ENV=prod|dev, SECRETS=path.hcl, TARGET=all|apps|infra|settings)"
	echo " all:"
	echo "   plan               - Plan all units (infra + manifests)           (ENV=prod|dev, SECRETS=path.hcl)"
	echo "   apply              - Apply all units (infra + manifests)          (ENV=prod|dev, SECRETS=path.hcl)"
	echo "   destroy            - DANGER: Destroy infra units only             (ENV=prod|dev, SECRETS=path.hcl)"
	echo " misc:"
	echo "   clean              - Remove generated .terragrunt-stack/ and .terraform/ directory"
	echo " secrets:"
	echo "   encrypt            - Encrypt secrets in place"
	echo "   decrypt            - Decrypt secrets in place"
	echo " packer:"
	echo "   build              - Build Packer images (only for hetzner)"


##~ ---------------------------------------------------------------------------- ~##
#  Generate stack units based on the specified environment.                        #
##~ ---------------------------------------------------------------------------- ~##
generate:
	command -v clear >/dev/null 2>&1 && clear || true
	echo "Checking secret file for $(ENV) stack: $(SECRETS)"
	if [ ! -f "$(SECRETS)" ]; then \
		echo "Error: Secrets file not found at $(SECRETS). Please create it or specify the correct path using SECRETS=path/to/secrets.hcl"; \
		exit 1; \
	elif sops filestatus $(SECRETS) | jq -r '.encrypted' | grep -q "true"; then \
		echo "Error: Secrets file at $(SECRETS) appears to be encrypted. Please decrypt it before proceeding."; \
		exit 1; \
	fi
	echo "Generating stack: $(ENV) ($(STACK_FILE))"
	terragrunt stack generate
	rm -rf $(STACK_DEEP_NESTED_DIRS)


##~ ---------------------------------------------------------------------------- ~##
# Infra plan/apply/destroy targets. These operate only on the infra units.         #
##~ ---------------------------------------------------------------------------- ~##
infra-plan: generate
	echo "Planning infra units..."
	$(TG_RUN_INFRA) plan -- -show-sensitive
	rm -rf $(STACK_NESTED_DIRS)

infra-apply: _check_values generate
	echo "Applying infra units..."
	$(TG_RUN_INFRA) apply
	rm -rf $(STACK_NESTED_DIRS)

infra-destroy: _check_values
	clear
	if [ ! -d "$(STACK_DIR)/infra/.terragrunt-stack" ]; then \
		echo "Error: Infra stack does not appear to be generated. Please run 'make infra-plan' or 'make infra-apply' first."; \
		exit 1; \
	fi
	echo "Destroying infra units..."
	terragrunt stack generate
	$(TG_RUN_INFRA) destroy
	rm -rf $(STACK_NESTED_DIRS)
	rm -rf $(STACK_DIR) .terraform

	
##~ ---------------------------------------------------------------------------- ~##
# Manifests plan/apply/destroy targets. These operate only on the manifest units.  #
##~ ---------------------------------------------------------------------------- ~##
manifests-plan: generate
	kubectl cluster-info > /dev/null || { echo "Error: kubeconfig is not valid or cluster is not reachable. Please check your kubeconfig and cluster status."; exit 1; }
	echo "Planning manifest units..."
	$(TG_RUN_MANIFESTS) plan -- -show-sensitive
	rm -rf $(STACK_NESTED_DIRS)

manifests-apply: _check_values generate
	kubectl cluster-info > /dev/null || { echo "Error: kubeconfig is not valid or cluster is not reachable. Please check your kubeconfig and cluster status."; exit 1; }
	echo "Applying manifest units..."
	find . -type f -iname '*public-domains.csv' -delete || true
	$(TG_RUN_MANIFESTS) apply
	rm -rf $(STACK_NESTED_DIRS)

manifests-destroy: _check_values
	clear
	kubectl cluster-info > /dev/null || { echo "Error: kubeconfig is not valid or cluster is not reachable. Please check your kubeconfig and cluster status."; exit 1; }
	echo "Destroying manifest units..."
	terragrunt stack generate
	$(TG_RUN_MANIFESTS) destroy
	rm -rf $(STACK_NESTED_DIRS)

	
##~ ---------------------------------------------------------------------------- ~##
# Legacy aliases                                                                   #
##~ ---------------------------------------------------------------------------- ~##
plan: generate
	$(TG_RUN_INFRA) plan -- -show-sensitive
	if kubectl config get-contexts "$(KUBE_CONTEXT)" > /dev/null 2>&1 && kubectl --context "$(KUBE_CONTEXT)" cluster-info > /dev/null 2>&1; then \
		if ! $(TG_RUN_MANIFESTS) plan; then \
			echo "Warning: manifests plan failed (kubeconfig/provider context issue). Infra plan succeeded."; \
		fi; \
	else \
		echo "Warning: kubeconfig context '$(KUBE_CONTEXT)' is not reachable; skipping manifests plan."; \
	fi
	rm -rf $(STACK_NESTED_DIRS)

apply: _check_values generate
	$(TG_RUN_INFRA) apply
	if kubectl cluster-info > /dev/null 2>&1; then \
		$(TG_RUN_MANIFESTS) apply; \
	else \
		echo "Warning: kubeconfig/cluster is not reachable; skipping manifests apply."; \
	fi
	rm -rf $(STACK_NESTED_DIRS)

destroy: _check_values
	clear
	if [ ! -d "$(STACK_DIR)" ]; then \
		echo "Error: Stack does not appear to be generated. Please run 'make generate' first."; \
		exit 1; \
	fi
	echo "Destroying infra units only: $(ENV)"
	terragrunt stack generate
	$(TG_RUN_INFRA) destroy
	rm -rf $(STACK_NESTED_DIRS)
	rm -rf $(STACK_DIR) .terraform

clean:
	read -p 'Are you sure you want to clean the stack? (y/n): ' -r answer; \
	if [ "$$answer" != "y" ]; then \
        echo "Aborted."; \
        exit 1; \
    fi
	terragrunt stack clean || true
	rm -rf $(STACK_DIR) .terraform/
	echo "Cleaned $(STACK_DIR)"


##~ ---------------------------------------------------------------------------- ~##
#  Packer build target. This is separate from the main stack targets since it may  #
# require different secrets and is only relevant for certain providers             #
# (e.g., Hetzner). It also handles its own encryption/decryption of secrets to     #
# avoid affecting the main stack secrets.                                          #
##~ ---------------------------------------------------------------------------- ~##
build:
	command -v clear >/dev/null 2>&1 && clear || true
	$(MAKE) _sops MODE=decrypt TARGET_FILE=packer/secret.hcl
	echo "Building Packer images..."
	cd packer && packer build -var-file=secret.hcl -var-file=prod.pkrvars.hcl . || true
	echo "Packer build completed successfully!"
	$(MAKE) _sops MODE=encrypt TARGET_FILE=packer/secret.hcl


##~ ---------------------------------------------------------------------------- ~##
#  Lint target. This runs formatters on all Terraform and HCL files in the stack,  #
##~ ---------------------------------------------------------------------------- ~##
lint:
	echo "Linting all files (*.hcl) ..."
	terragrunt hcl fmt || true
	echo "Linting Terraform files (*.tf) ..."
	cd modules && tofu fmt -recursive
	echo "Linting completed successfully!"