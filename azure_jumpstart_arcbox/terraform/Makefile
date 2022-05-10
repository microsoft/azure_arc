init:
	docker-compose run --rm terraform init -input=false

format:
	docker-compose run --rm terraform fmt --recursive

format_check:
	docker-compose run --rm terraform fmt --recursive -check

validate:
	docker-compose run --rm terraform validate

plan:
	docker-compose run --rm terraform plan -var-file=deployments/${DEPLOYMENT}/variables.tfvars

state:
	docker-compose run --rm terraform state list 

state-rm:
	docker-compose run --rm terraform state rm $(arg)

output:
	docker-compose run --rm terraform output

apply:
	docker-compose run --rm terraform apply --auto-approve -var-file=deployments/${DEPLOYMENT}/variables.tfvars

destroy-plan:
	docker-compose run --rm terraform workspace select ${OpGroup}
	docker-compose run --rm terraform plan -destroy -var-file=configuration/${OpGroup}/${OpGroup}.tfvars

destroy:
	docker-compose run --rm terraform workspace select ${OpGroup}
	docker-compose run --rm terraform destroy --auto-approve -var-file=configuration/${OpGroup}/${OpGroup}.tfvars

login:
	docker-compose run --rm terraform login iac.wpp.cloud

debug1:
	@echo 'var-file: ${OpGroup}'
	debug: ## terraform debug: Enters the docker container for you so you can run commands and/or check configurations

debug: 
	docker-compose run --rm --entrypoint /bin/sh terraform
