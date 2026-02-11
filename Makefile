.PHONY: default init
.SILENT: 

default:
	echo "Available targets:"
	echo " general:       - General targets"
	echo "   init         - Initialize symlinks for providers.tf"
	echo "   lint         - Lint Terraform files"
	echo " secrets:       - Encrypt/decrypt secrets with SOPS"
	echo "   encrypt-all  - Encrypt all secrets files"
	echo "   decrypt-all  - Decrypt all secrets files"
	echo " dev:           - Development environment"
	echo "   dev-build    - Build Packer images for development"
	echo "   dev-plan     - Plan development infrastructure"
	echo "   dev-apply    - Apply development infrastructure"
	echo "   dev-destroy  - DANGER: Destroy development infrastructure"
	echo " prod:          - Production environment"
	echo "   build        - Build Packer images"
	echo "   plan         - Plan production infrastructure"
	echo "   apply        - Apply production infrastructure"
	echo "   destroy      - DANGER: Destroy production infrastructure"

_init:
	echo "Creating symlinks for tofu environments..."
	ln -sf ../providers.tf tofu/dev/providers.tf
	ln -sf ../providers.tf tofu/prod/providers.tf
	echo "Symlinks created successfully!"
	
_sops:
	set -euo pipefail; \
	: "$${SOPS_AGE_KEY_FILE:?SOPS_AGE_KEY_FILE is not set}"; \
	: "$${TARGET_FILE:?TARGET_FILE is not set}"; \
	: "$${MODE:?MODE is not set}"; \
	[ -f "$$SOPS_AGE_KEY_FILE" ] || { echo "Error: SOPS_AGE_KEY_FILE does not exist at $$SOPS_AGE_KEY_FILE"; exit 1; }; \
	[ -f "$$TARGET_FILE" ] || { echo "Error: TARGET_FILE does not exist at $$TARGET_FILE"; exit 1; }; \
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


	
decrypt-all:
	$(MAKE) _sops MODE=decrypt TARGET_FILE=packer/secret.hcl
	$(MAKE) _sops MODE=decrypt TARGET_FILE=tofu/secret.tfvars

encrypt-all:
	$(MAKE) _sops MODE=encrypt TARGET_FILE=packer/secret.hcl
	$(MAKE) _sops MODE=encrypt TARGET_FILE=tofu/secret.tfvars	

	
	
build:
	clear
	$(MAKE) _sops MODE=decrypt TARGET_FILE=packer/secret.hcl
	echo "Building Packer images..."
	cd packer && packer build -var-file=secret.hcl -var-file=prod.pkrvars.hcl . || true
	echo "Packer build completed successfully!"
	$(MAKE) _sops MODE=encrypt TARGET_FILE=packer/secret.hcl

plan: _init
	clear
	$(MAKE) _sops MODE=decrypt TARGET_FILE=tofu/secret.tfvars
	echo "Planning production infrastructure with Terraform..."
	cd tofu/prod && \
	  tofu init -upgrade && \
      tofu plan -var-file=../secret.tfvars -var-file=variables.tfvars || true
	echo "Terraform plan completed successfully!"
	$(MAKE) _sops MODE=encrypt TARGET_FILE=tofu/secret.tfvars

apply:
	clear
	$(MAKE) _sops MODE=decrypt TARGET_FILE=tofu/secret.tfvars
	echo "Applying production infrastructure with Terraform..."
	cd tofu/prod && \
	  tofu init -upgrade && \
	  tofu apply -var-file=../secret.tfvars -var-file=variables.tfvars -auto-approve || true
	echo "Terraform apply completed successfully!"
	$(MAKE) _sops MODE=encrypt TARGET_FILE=tofu/secret.tfvars

destroy:
	clear
	$(MAKE) _sops MODE=decrypt TARGET_FILE=tofu/secret.tfvars
	echo "Destroying production infrastructure with Terraform..."
	cd tofu/prod && \
		tofu init -upgrade && \
		tofu destroy -var-file=../secret.tfvars -var-file=variables.tfvars || true
	echo "Terraform destroy completed successfully!"
	$(MAKE) _sops MODE=encrypt TARGET_FILE=tofu/secret.tfvars



dev-build:
	clear
	echo "Not implemented yet..."
	# $(MAKE) _sops MODE=decrypt TARGET_FILE=packer/secret.hcl
	# echo "Building Packer images..."
	# cd packer && packer build -var-file=secret.hcl -var-file=dev.pkrvars.hcl . || true
	# echo "Packer build completed successfully!"
	# $(MAKE) _sops MODE=encrypt TARGET_FILE=packer/secret.hcl
	
dev-plan:
	clear
	
dev-apply:
	clear
	
dev-destroy:
	clear
	
lint:
	echo "Linting Terraform and HCL files..."
	cd packer && \
	packer fmt *pkr*.hcl && \
    cd ../tofu && \
    tofu fmt -recursive
	echo "Linting completed successfully!"
