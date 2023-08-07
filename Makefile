DOCKER_COMPOSE=$$(command -v docker-compose)
NO_DATA_CONTAINERS=alertmanager,mailhog,stunnel,nodeexporter,cadvisor,pushgateway,caddy

CURRENT_UID=$(shell id -u)
CURRENT_GID=$(shell id -g)

##
## Environnement
## ------
##

.env: .env.dist
	@if [ -f .env ]; \
	then \
		echo '/!\ The .env.dist file has changed. Please check your .env file (this message will not be displayed again).';\
		touch .env;\
		exit 1;\
	else \
		echo "cp .env.dist .env" ;\
		cp .env.dist .env ;\
		sed -i "s#UID=1000#UID=${CURRENT_UID}#" .env ;\
		sed -i "s#GID=1000#GID=${CURRENT_GID}#" .env ;\
	fi

envs: ## Create .env files
envs: .env

delete-env: ## Delete all .env files
delete-env:
	@find . -name '.env' -delete ;

regen-envs: ## Delete & Recreate .env files
regen-envs: delete-env envs

##
## Docker
## ------
##

docker-pull-build: ## Build stack from Dockerfile and Pull image from hub
docker-pull-build:
	@"$(DOCKER_COMPOSE)" pull --quiet --ignore-pull-failures 2> /dev/null
	@"$(DOCKER_COMPOSE)" build --pull

docker-build: ## Build stack from Dockerfile
docker-build:
	@"$(DOCKER_COMPOSE)" build --pull

docker-kill: ## Kill stack, remove container & volume (you loose your database)
docker-kill:
	@"$(DOCKER_COMPOSE)" kill
	@"$(DOCKER_COMPOSE)" down --volumes --remove-orphans

docker-start: ## Start all docker based on docker-compose.json
docker-start:
	@"$(DOCKER_COMPOSE)" up -d --remove-orphans --no-recreate

docker-stop: ## Gracefully shutdown the stack
docker-stop:
	@"$(DOCKER_COMPOSE)" stop

docker-down: ## Shutdown the stack and remove datas
docker-down: docker-kill
	@"$(DOCKER_COMPOSE)" down -v

docker-restart: ## Gracefully restart stack
docker-restart: docker-stop docker-start

docker-refresh: ## Gracefully restart stack, delete container without data
docker-refresh: docker-stop docker-rm-no-data docker-start

docker-kill-no-data: ## Kill docker that doesn't own datas
docker-kill-no-data:
	@"$(DOCKER_COMPOSE)" kill $(NO_DATA_CONTAINERS)

docker-rm-no-data: ## Remove docker that doesn't own datas
docker-rm-no-data:
	@"$(DOCKER_COMPOSE)" rm -f $(NO_DATA_CONTAINERS)

docker-force-restart: ## Kill container and restart
docker-force-restart: docker-kill docker-start

docker-recreate: ## Down & Start
docker-recreate: docker-down docker-start

docker-rebuild: ## Kill, Build & Start
docker-rebuild: docker-kill docker-build docker-start

docker-status: ## Print status
docker-status:
	@"$(DOCKER_COMPOSE)" ps

.PHONY: docker-kill docker-stop docker-restart docker-force-restart docker-recreate docker-status docker-down docker-rebuild

##
## Starting project
## --------
##

init: ## Init stack & start
init: envs docker-pull-build start

stop: ## Stop stack
stop: docker-stop

start: ## Start stack
start: droits docker-start

restart: ## Restart stack
restart: stop start

reset: ## Rebuild container and start
reset: regen-envs docker-rebuild start

update: ## Update stack
update: stop docker-kill docker-pull-build start

droits: ## Add permissions on volumes folders
droits:
	mkdir -p ./grafana_data
	mkdir -p ./prometheus_data
	sudo chown -R $(shell id -un):$(shell id -gn) ./grafana_data ./prometheus_data
	sudo chmod -R 777 ./grafana_data ./prometheus_data

# Default goal and help

.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'
.PHONY: help
