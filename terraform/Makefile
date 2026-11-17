AWS_PROFILE ?= auto-repair

export AWS_PROFILE

.PHONY: init plan up down outputs

init:
	terraform init -input=false

plan:
	terraform plan -input=false

up:
	terraform apply -input=false -auto-approve

down:
	terraform destroy -input=false -auto-approve

outputs:
	terraform output
