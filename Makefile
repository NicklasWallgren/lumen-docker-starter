# The default environment file
ENVIRONMENT_FILE=$(shell pwd)/.env

# The default lumen directory
PROJECT_DIRECTORY=$(shell pwd)/lumen

# Available docker containers
CONTAINERS=php-fpm php-cli nginx mysql memcached

default: run

# Start the containers
run: prerequisite build

# Start individual container
start: prerequisite valid-container
	- docker-compose -f docker/docker-compose.dev.yml up -d --build $(filter-out $@,$(MAKECMDGOALS))

# Stop individual container
stop: prerequisite valid-container
	- docker-compose -f docker/docker-compose.dev.yml stop $(filter-out $@,$(MAKECMDGOALS))

# Halts the docker containers
halt: prerequisite
	- docker-compose -f docker/docker-compose.dev.yml kill

# Build the docker containers and the project
build: prerequisite build-containers build-project update-project
	- docker-compose -f docker/docker-compose.dev.yml up -d --build

# Build the containers
build-containers:
	- docker-compose -f docker/docker-compose.dev.yml up -d --build

# Build the project
build-project:
# Check whether the project has been initialized
ifeq ("$(wildcard $(PROJECT_DIRECTORY))","")
	- docker-compose -f docker/docker-compose.dev.yml exec php-cli composer --no-scripts create-project laravel/lumen lumen

	# Install using no scripts, run the script after the installation has finished and the env file is in place
	- cp config/lumen/.env lumen/.env
endif

# Update the project and the dependencies
update-project:
	- docker-compose -f docker/docker-compose.dev.yml exec php-cli composer -d=lumen --ansi update

# Remove the docker containers and deletes project dependencies
clean: prerequisite prompt-continue
	# Remove the dependencies
	- rm -rf lumen/vendor
	# Remove the docker containers
	- docker-compose -f docker/docker-compose.dev.yml down

# Echos the container status
status: prerequisite
	- docker-compose -f docker/docker-compose.dev.yml ps

# Opens a bash prompt to the php cli container
bash-cli: prerequisite
	- docker-compose -f docker/docker-compose.dev.yml exec php-cli bash

# Opens a bash prompt to the php fpm container
bash-fpm: prerequisite
	- docker-compose -f docker/docker-compose.dev.yml exec php-fpm bash

# Opens a bash prompt to the php fpm container
bash-mysql: prerequisite
	- docker-compose -f docker/docker-compose.dev.yml exec mysql bash

# Opens a bash prompt to the memcached container
bash-memcached: prerequisite
	- docker-compose -f docker/docker-compose.dev.yml exec memcached bash

# Opens a bash prompt to the nginx container
bash-nginx: prerequisite
	- docker-compose -f docker/docker-compose.dev.yml exec nginx bash

# Opens the mysql cli
mysql-cli:
	- docker-compose -f docker/docker-compose.dev.yml exec mysql mysql -u root -p$(MYSQL_ROOT_PASSWORD)

# Validates the prerequisites such as environment variable
prerequisite: check-environment
include .env
export ENV_FILE = $(ENVIRONMENT_FILE)

# Validates the environment variables
check-environment:
# Check whether the environment file exists
ifeq ("$(wildcard $(ENVIRONMENT_FILE))","")
	- @echo Copying "docker/.env.default";
	- cp docker/.env.default .env
endif
# Check whether the docker binary is available
ifeq (, $(shell which docker-compose))
	$(error "No docker-compose in $(PATH), consider installing docker")
endif

# Validates the containers
valid-container:
ifeq ($(filter $(filter-out $@,$(MAKECMDGOALS)),$(CONTAINERS)),)
	$(error Invalid container provided "$(filter-out $@,$(MAKECMDGOALS))")
endif

# Prompt to continue
prompt-continue:
	@while [ -z "$$CONTINUE" ]; do \
		read -r -p "Would you like to continue? [y]" CONTINUE; \
	done ; \
	if [ ! $$CONTINUE == "y" ]; then \
        echo "Exiting." ; \
        exit 1 ; \
    fi

%:
	@: