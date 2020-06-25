.SILENT:

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-12s\033[0m%s\n", $$1, $$2 }'

create-user: # local development without docker
	./make.sh create-user

dev: # local development without docker
	./make.sh dev

build: # build the production image
	./make.sh build
	
run: # run the built production image
	./make.sh run

rm: # remove the running container built production
	./make.sh rm

ecr-create: # 
	./make.sh ecr-create

ecr-push: # 
	./make.sh ecr-push

ecr-destroy: # 
	./make.sh ecr-destroy

tf-init: # tf-init
	./make.sh tf-init

tf-validate: # tf-validate
	./make.sh tf-validate

tf-apply: # tf-apply
	./make.sh tf-apply

tf-scale-up: # scale to 3
	./make.sh tf-scale-up

tf-scale-down: # scale to 1 (warn: target deregistration take time)
	./make.sh tf-scale-down

tf-destroy: # tf-destroy
	./make.sh tf-destroy