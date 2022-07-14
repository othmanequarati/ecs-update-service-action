#!/bin/sh

# This function initializes the system prior to main processing
init () {
    ulimit -c 0       # Set Core size to 0
    set -e
    export AWS_DEFAULT_OUTPUT="${AWS_DEFAULT_OUTPUT}"
    #importDotEnv
}

# importDotEnv () {
#     if [ -f .env ]; then
#     	export $(sed 's/[[:blank:]]//g; /^#/d' .env | xargs)
#     fi
# }

# Format strings for logfunctions
format () {
    echo "$(date +"%d/%m/%y %T") [${1}]";
}

loginfo ()  { echo  "\n\033[32m$(format INFO)\033[0m ${@}"; }
lognotice ()  { echo  "\n\033[34m$(format NOTICE)\033[0m ${@}"; }
logwarning () { echo  "\n\033[33m$(format WARNING)\033[0m ${@}"; }
logerror () { echo  "\n\033[31m$(format ERROR)\033[0m ${@}" 1>&2; }

#aws configure
aws_configure_profile(){

aws configure --profile ${INPUT_AWS_PROFILE} <<-EOF
${INPUT_AWS_ACCESS_KEY_ID}
${INPUT_AWS_SECRET_ACCESS_KEY}
${INPUT_AWS_REGION}
text
EOF
   loginfo "aws configuration profile is done"
}

ecs_configure_profile(){
    if [ -n "${INPUT_AWS_PROFILE}" ]
    then
        ecs-cli configure profile --profile-name ${INPUT_AWS_PROFILE}
        loginfo "ecs-cli configuration profile is done"
    else
        loginfo "No AWS profile configured"
        exit 1
    fi
}

ecs_config_name_cluster(){
    if [ -n "${INPUT_CLUSTER_NAME}" ] && [ -n "${INPUT_LAUNCH_TYPE}" ] && [ -n "${INPUT_AWS_REGION}" ] && [ -n "${INPUT_CLUSTER_CONFIG_NAME}" ] 
    then
        ecs-cli configure --cluster ${INPUT_CLUSTER_NAME}  --default-launch-type ${INPUT_LAUNCH_TYPE}  --region ${INPUT_AWS_REGION} --config-name ${INPUT_CLUSTER_CONFIG_NAME}  
        loginfo "ecs-cli configuration config name cluter is done"
    else
        loginfo "No ECS profile configured"
        exit 1
    fi
    
}

#Extract targetgroup arn
get_targetgroup_arn(){
    if [ -n "${INPUT_AWS_PROFILE}" ] && [ -n "${INPUT_ECS_TARGET_GROUP_NAME}" ]
    then
        aws --profile ${INPUT_AWS_PROFILE} elbv2 describe-target-groups --name "${INPUT_ECS_TARGET_GROUP_NAME}" | jq -r '.TargetGroups[] | .TargetGroupArn'
        loginfo "Retrieve targetgroup value"
    else
        logerror "Error on configuration configured"
        exit 1
    fi
    
}

access_to_ecs_folder(){
    if [ -n "${INPUT_PATH_TO_ECS_FOLDER}" ]
    then
        cd "${INPUT_PATH_TO_ECS_FOLDER}"
    else
        loginfo "No path configured"
        exit 1
    fi
}

#UPDATE ECS
ecs_run_update(){
    ecs-cli compose \
    --cluster-config ${INPUT_CLUSTER_CONFIG_NAME} --ecs-profile ${INPUT_AWS_PROFILE} \
	--region ${INPUT_AWS_REGION} \
    --project-name ${INPUT_PROJECT_NAME} \
    --ecs-params ${INPUT_ECS_PARAMS_PATH} \
    service up \
	--launch-type ${INPUT_LAUNCH_TYPE} \
	--deployment-max-percent ${INPUT_DEPLOYMENT_MAX} --deployment-min-healthy-percent ${INPUT_DEPLOYMENT_MIN} \
	--enable-service-discovery \
	--create-log-groups \
    --target-groups "targetGroupArn=$(get_targetgroup_arn),containerName=${INPUT_CONTAINER_NAME},containerPort=${INPUT_CONTAINER_PORT}" \
	--force-deployment
}

main(){
    init "$@"
    #check variables if not empty
    if [ -n "${INPUT_AWS_ACCESS_KEY_ID}" ] && [ -n "${INPUT_AWS_SECRET_ACCESS_KEY}" ] && [ -n "${INPUT_AWS_REGION}" ] 
    then
        #call function to configure profile
        aws_configure_profile
        ecs_configure_profile
        ecs_config_name_cluster
    else
        logerror "keys are not configured"
        exit 1
    fi

    #get value ecs_name
    TARGET_GROUP_ARN="$(get_targetgroup_arn)"

    if [ -n "${TARGET_GROUP_ARN}" ]
    then
        access_to_ecs_folder
        ecs_run_update
        loginfo "ECS service was updated"
    else
        
        logerror "the target group is not defined"
    fi

    
    exit 0
}

main "$@"