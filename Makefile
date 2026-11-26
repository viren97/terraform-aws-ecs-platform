ENV ?= dev
TF  := terraform -chdir=stack

.PHONY: init plan apply fmt lint validate

init:
	$(TF) init -reconfigure -backend-config=../envs/$(ENV).s3.tfbackend

plan:
	$(TF) plan -var-file=../envs/$(ENV).tfvars -out=$(ENV).tfplan

apply:
	$(TF) apply $(ENV).tfplan

fmt:
	terraform fmt -recursive

lint:
	tflint --recursive --config "$(CURDIR)/.tflint.hcl"

validate:
	@for d in stack modules/*; do (cd $$d && terraform init -backend=false -input=false >/dev/null && terraform validate) || exit 1; done
