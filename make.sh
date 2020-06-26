#!/bin/bash

#
# variables
#

# AWS variables
AWS_PROFILE=default
AWS_REGION=eu-west-3
# project name
PROJECT_NAME=github-actions-ecr
# Docker image name
DOCKER_IMAGE=github-actions-ecr
# terraform
export TF_VAR_project_name=$PROJECT_NAME
export TF_VAR_region=$AWS_REGION
export TF_VAR_profile=$AWS_PROFILE


# the directory containing the script file
dir="$(cd "$(dirname "$0")"; pwd)"
cd "$dir"


log()   { echo -e "\e[30;47m ${1^^} \e[0m ${@:2}"; }        # $1 uppercase background white
info()  { echo -e "\e[48;5;28m ${1^^} \e[0m ${@:2}"; }      # $1 uppercase background green
warn()  { echo -e "\e[48;5;202m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background orange
error() { echo -e "\e[48;5;196m ${1^^} \e[0m ${@:2}" >&2; } # $1 uppercase background red


# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

create-user() {
    [[ -f "$dir/secrets.sh" ]] && { warn warn user already exists; return; }
    
    aws iam create-user \
        --user-name $PROJECT_NAME \
        --profile $AWS_PROFILE \
        2>/dev/null

    aws iam attach-user-policy \
        --user-name $PROJECT_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess \
        --profile $AWS_PROFILE

    aws iam attach-user-policy \
        --user-name $PROJECT_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess \
        --profile $AWS_PROFILE

    # root account id
    ACCOUNT_ID=$(aws sts get-caller-identity \
        --query 'Account' \
        --profile $AWS_PROFILE \
        --output text)
    log ACCOUNT_ID $ACCOUNT_ID

    local key=$(aws iam create-access-key \
        --user-name $PROJECT_NAME \
        --query 'AccessKey.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey}' \
        --profile $AWS_PROFILE \
        2>/dev/null)

    AWS_ACCESS_KEY_ID=$(echo "$key" | jq '.AccessKeyId' --raw-output)
    log AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID
    
    AWS_SECRET_ACCESS_KEY=$(echo "$key" | jq '.SecretAccessKey' --raw-output)
    log AWS_SECRET_ACCESS_KEY $AWS_SECRET_ACCESS_KEY

    cat > "$dir/secrets.sh" << EOF
ACCOUNT_ID=$ACCOUNT_ID
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
EOF
}

# local development without docker
dev() {
    cd "$dir/duck"
    [[ ! -d node_modules ]] && { log install node modules; npm install; }
    NODE_ENV=development PORT=3000 node .
}

# build the production image
build() {
    cd "$dir/duck"
    VERSION=$(jq --raw-output '.version' package.json)
    log build $DOCKER_IMAGE:$VERSION
    docker image build \
        --tag $DOCKER_IMAGE:latest \
        --tag $DOCKER_IMAGE:$VERSION \
        .
}

# run the latest built production image on localhost
run() {
    [[ -n $(docker ps --format '{{.Names}}' | grep $PROJECT_NAME) ]] \
        && { error error container already exists; return; }
    log run $DOCKER_IMAGE on http://localhost:3000
    docker run \
        --detach \
        --name $PROJECT_NAME \
        --publish 3000:80 \
        $DOCKER_IMAGE
}

# remove the running container
rm() {
    [[ -z $(docker ps --format '{{.Names}}' | grep $PROJECT_NAME) ]]  \
        && { warn warn no running container found; return; }
    docker container rm \
        --force $PROJECT_NAME
}

ecr-create() {
    local repo=$(aws ecr describe-repositories \
        --repository-names $PROJECT_NAME \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        2>/dev/null)
    [[ -n "$repo" ]] && { warn warn repository already exists; return; }

    REPOSITORY_URI=$(aws ecr create-repository \
        --repository-name $PROJECT_NAME \
        --query 'repository.repositoryUri' \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        --output text \
        2>/dev/null)
    log REPOSITORY_URI $REPOSITORY_URI
}

ecr-destroy() {
    local repo=$(aws ecr describe-repositories \
        --repository-names $PROJECT_NAME \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        2>/dev/null)
    [[ -z "$repo" ]] && { warn warn no repository found; return; }

    aws ecr delete-repository \
        --repository-name $PROJECT_NAME \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        1>/dev/null
}

# push the 1.0.0 version to ecr
ecr-push() {
    local online=$(aws ecr describe-images \
        --repository-name $DOCKER_IMAGE \
        --image-ids imageTag=1.0.0 \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        2>/dev/null)
    [[ -n "$online" ]] && { warn abort $DOCKER_IMAGE:1.0.0 already on repository; return; }

    local image=$(docker images \
        --format '{{.Repository}}:{{.Tag}}' \
        | grep ^$DOCKER_IMAGE:1.0.0)
    [[ -z "$image" ]] && { warn warn image $DOCKER_IMAGE:v1.0.0 not found; return; }

    REPOSITORY_URI=$(aws ecr describe-repositories \
        --query "repositories[?repositoryName == '$PROJECT_NAME'].repositoryUri" \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        --output text)
    [[ -z "$REPOSITORY_URI" ]] && { warn warn no repository found; return; }
    log REPOSITORY_URI $REPOSITORY_URI

    # root account id
    ACCOUNT_ID=$(aws sts get-caller-identity \
        --query 'Account' \
        --profile $AWS_PROFILE \
        --output text)
    log ACCOUNT_ID $ACCOUNT_ID

    # add login data into /home/$USER/.docker/config.json
    aws ecr get-login-password \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        | docker login \
        --username AWS \
        --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    docker tag $DOCKER_IMAGE:latest $REPOSITORY_URI:1.0.0

    log push $REPOSITORY_URI:1.0.0
    docker push $REPOSITORY_URI:1.0.0
}

tf-init() {
    cd "$dir/infra"
    terraform init
}

tf-validate() {
    cd "$dir/infra"
    terraform fmt -recursive
	terraform validate
}

tf-apply() {
    local online=$(aws ecr describe-images \
        --repository-name $DOCKER_IMAGE \
        --image-ids imageTag=1.0.0 \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        2>/dev/null)
    [[ -z "$online" ]] && { warn abort $DOCKER_IMAGE:1.0.0 not found on repository; return; }

    # root account id
    ACCOUNT_ID=$(aws sts get-caller-identity \
        --query 'Account' \
        --profile $AWS_PROFILE \
        --output text)

    cd "$dir/infra"
    export TF_VAR_ecr_image=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME:1.0.0
    terraform plan \
        -out=terraform.plan

    terraform apply \
        -auto-approve \
        terraform.plan
}

tf-scale-up() {
    export TF_VAR_desired_count=3
    tf-apply
}

tf-scale-down() {
    export TF_VAR_desired_count=2
    tf-apply
}

tf-destroy() {
    cd "$dir/infra"
    terraform destroy \
        -auto-approve
}

# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info execute $1; eval $1; } || usage;
exit 0
