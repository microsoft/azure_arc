# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

TARGET_MAX_CHAR_NUM=20
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target> DEPLOYMENT=${YELLOW}testbed1${RESET} '
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

.PHONY:	init
## Terraform init
init:
	docker-compose run --rm terraform init -input=false

format:
	docker-compose run --rm terraform fmt --recursive

format_check:
	docker-compose run --rm terraform fmt --recursive -check

validate:
	docker-compose run --rm terraform validate

.PHONY:	plan
## Terraform plan
plan:
	docker-compose run --rm terraform plan -var-file=deployments/${DEPLOYMENT}/variables.tfvars

state:
	docker-compose run --rm terraform state list 

state-rm:
	docker-compose run --rm terraform state rm $(arg)

output:
	docker-compose run --rm terraform output

.PHONY:	apply
## Terraform apply
apply:
	docker-compose run --rm terraform apply --auto-approve -var-file=deployments/${DEPLOYMENT}/variables.tfvars


destroy:
	docker-compose run --rm terraform destroy --auto-approve -var-file=deployments/${DEPLOYMENT}/variables.tfvars

