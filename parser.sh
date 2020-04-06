#!/usr/bin/env bash

# set -ex

print_red() {
  printf '%b' "\033[91m$1\033[0m\n"
}

print_green() {
  printf '%b' "\033[92m$1\033[0m\n"
}

check_cmd() {
  which "$1" >/dev/null || { print_red "'$1' command is not available, please install it first, then try again" && exit 1; }
}

ENV_FILE='.env'

if [ -f $ENV_FILE ]; then
	source .env
else
	echo "Could not found ${ENV_FILE}"
	exit
fi

check_var() {
	local name=$1
	local value=${!name}
	if [ -z "$value" ]; then
		print_red "'$name' variable is not available, please check vars in $ENV_FILE, then try again" && exit 1;
	fi
}

check_variables() {
  local vars="COMPOSE_PROJECT_NAME STORE ENV"

	for var in ${vars}; do
		check_var $var
	done
}

check_cmds() {
	local vars="DOCKER_COMPOSE"

	for var in ${vars}; do
		check_cmd ${!var}
	done
}

check_cmds
check_variables

COMPOSE_FILE="docker-compose.yaml"
if [ ! -f $COMPOSE_FILE ]; then
	print_red "${COMPOSE_FILE} not found"
fi
export COMPOSE_FILE

function pull_service() {
	local name=$1

  array=${images[$name]}
  for image in $array; do
  	docker pull $image
  done
}

function pull() {

	local name=$1

	if [[ "X$name" == "X" ]];
	then
		for item in $services;
		do
			pull_service $item
		done
	else
		pull_service $name
	fi
}

function stop() {
	local name=$1

	if [[ "X$name" == "X" ]]; then
		$DOCKER_COMPOSE down
  	else
  		array=${deps[$name]}
  		for item in $array; do
  			$DOCKER_COMPOSE stop $item
  		done
  	fi
}

function start() {
	local name=$1

	if [[ "X$name" == "X" ]];
	then
		pull
		stop
		$DOCKER_COMPOSE up --build -d
	else
		pull $name
		array=${deps[$name]}
  	for item in $array; do
  		$DOCKER_COMPOSE up -d --no-deps $item
  	done
	fi
}

function restart() {
	local name=$1

	if [[ "X$name" == "X" ]];
	then
		stop
		sleep 1
		start
	else
		pull_service $name
		array=${deps[$name]}
  	for item in $array; do
  		$DOCKER_COMPOSE rm -s -f $item
			$DOCKER_COMPOSE up -d --force-recreate --no-deps $item
		done
	fi
}

function reload() {
	local name=$1
	if [ -n "$name" ]; then
		$DOCKER_COMPOSE up -d --build --force-recreate --no-deps $name
	fi
}

function listup() {
	$DOCKER_COMPOSE ps
}

function services() {
	echo "Services list: "
	for item in $services;
	do
		echo "  $item"
	done
}

trap stop EXIT

services="
parser
"

declare -A images
images["parser"]="
aazayats/claim-parser:latest
"

declare -A deps
deps["parser"]="
claim-parser
"

function usage() {
  echo "
Usage: $0 [options]
Options:
    start [service_name]    Start service (if defined) / or whole stack
    restart [service_name]  Restart service (if defined) / or whole stack
    stop [service_name]     Remove service (if defined) / or whole stack
    ps                      Print list of running $STACK services
    services                Print list of $STACK services
    pull [service_name]     Pull docker images for serivce or whole stack
    help                    Print this help message
    init                    Init letsencrypt
"
}
while true ; do
	case "$1" in
		start)     start $2         ; break ;;
		restart)   restart $2       ; break ;;
		stop)      stop $2          ; break ;;
		pull)      pull $2          ; break ;;
		ps)        listup           ; break ;;
		reload)    reload $2        ; break ;;
		services)  services         ; break ;;
    init)      init             ; break ;;
		*)         usage            ; break ;;
  esac
done

trap - EXIT
