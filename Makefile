default:
	@echo "Available targets:"
	@echo " general:       - General targets"
	@echo "   init         - Initialize symlinks for providers.tf"
	@echo "   build        - Build Packer images (prod)"
	@echo "   build-dev    - Build Packer images (dev)"
	@echo "   build-prod   - Build Packer images (prod)"
	@echo "   lint         - Lint Terraform files"
	@echo " dev:           - Development environment"
	@echo "   dev-plan     - Plan development infrastructure"
	@echo "   dev-apply    - Apply development infrastructure"
	@echo "   dev-destroy  - DANGER: Destroy development infrastructure"
	@echo " prod:          - Production environment"
	@echo "   plan         - Plan production infrastructure"
	@echo "   apply        - Apply production infrastructure"
	@echo "   destroy      - DANGER: Destroy production infrastructure"

init:
	@echo "Creating symlinks for providers.tf..."
	@ln -sf ../providers.tf tofu/dev/providers.tf
	@ln -sf ../providers.tf tofu/prod/providers.tf
	@echo "Symlinks created successfully!"

_packer:
	@set -euo pipefail; \
	: "$${SOPS_AGE_KEY_FILE:?Error: SOPS_AGE_KEY_FILE environment variable is not set.}"; \
	cd packer; \
	cat secret.hcl | grep -q 'sops' && sops -i -d secret.hcl; \
	packer build -var-file="$(VARS_FILE)" -var-file="secret.hcl" .
	

build-dev:
	@$(MAKE) _packer VARS_FILE=dev.pkrvars.hcl

build-prod:
	@$(MAKE) _packer VARS_FILE=prod.pkrvars.hcl

build: build-prod

dev-plan: init
	clear && \
	cd tofu/dev && \
	tofu init -upgrade && \
	tofu plan --var-file=../config-dev.tfvars

plan: init
	clear && \
	cd tofu/prod && \
	tofu init -upgrade && \
	tofu plan --var-file=../config-prod.tfvars -var-file=../secrets.tfvars

dev-apply:
	cd tofu/dev && \
	tofu apply -var-file=../config-dev.tfvars

apply:
	cd tofu/prod && \
	tofu apply -var-file=../config-prod.tfvars -var-file=../secrets.tfvars

lint:
	cd packer && \
    packer fmt *pkr*.hcl && \
	cd ../tofu && \
	tofu fmt -recursive

dev-destroy:
	cd tofu/dev && \
	tofu destroy -var-file=../config-dev.tfvars

destroy:
	cd tofu/prod && \
	tofu destroy -var-file=../config-prod.tfvars -var-file=../secrets.tfvars

.PHONY: default init build build-dev build-prod dev-plan plan dev-apply apply lint dev-destroy destroy
