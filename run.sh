#!/bin/sh
# set -x
# yes/noで応答
PROJECT_NAME=cloudformation-handson
KEY_PAIR_NAME=cloudformation-handson
ENVIORNMENT_NAME=dev
PROFILE=cloudformation-handson
APP_S3_BUCKET=cloudformation-hands-on-api
APP_S3_KEY=sample.zip
SERVICE_NAME=api
PRIVATE_DOMAIN_NAME=private-cloudformation-handson.com
DOMAIN_NAME=public-cloudformation-handson.com
CLOUDFORMATION_TEMPLATE_BUCKET=cloudformation-hands-on-resource

isALreadyExistStack(){
  # $1 is argument for function
  local response=$(aws cloudformation describe-stacks --stack-name $1 --profile $PROFILE)
  local result=$(echo $response | tr -d '[:space:]' | grep StackId | wc -c)
  # return string
  echo $result
}

showOutputs(){
  # $1 is argument for function
  local response=$(aws cloudformation describe-stacks --stack-name $1 --profile $PROFILE | jq -r '.Stacks[].Outputs[]')
  echo $response
}


aws s3api create-bucket \
  --bucket $CLOUDFORMATION_TEMPLATE_BUCKET \
  --region ap-northeast-1 \
  --profile $PROFILE \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

aws s3api create-bucket \
  --bucket $APP_S3_BUCKET \
  --region ap-northeast-1 \
  --profile $PROFILE \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

aws s3 cp ${APP_S3_KEY} s3://${APP_S3_BUCKET}/ \
  --profile=$PROFILE \
  --region ap-northeast-1

#----------------------------------------------------------
#  vpc
#----------------------------------------------------------
if test `isALreadyExistStack ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc` -ne 0;then
  # すでに存在するものへの変更
  aws cloudformation deploy \
    --template-file vpc.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME \
    KeyPairName=$KEY_PAIR_NAME
  showOutputs ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc
else
  # なかったら作成する
  aws cloudformation create-stack \
    --template-body file://vpc.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME \
    ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME
  showOutputs ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc
fi


#----------------------------------------------------------
#  dns depends on vpc
#----------------------------------------------------------
if test `isALreadyExistStack ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns` -ne 0;then
  # すでに存在するものへの変更
  aws cloudformation deploy \
    --template-file route53.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME
  showOutputs ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns
else
  # なかったら作成する
  aws cloudformation create-stack \
    --template-body file://route53.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=DomainName,ParameterValue=${DOMAIN_NAME}. \
    ParameterKey=PrivateDomainName,ParameterValue=${PRIVATE_DOMAIN_NAME}. \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME
  showOutputs ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns
fi

#----------------------------------------------------------
#  db dependds on db
#----------------------------------------------------------
if test `isALreadyExistStack ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db` -ne 0;then
  # すでに存在するものへの変更
  aws cloudformation deploy \
    --template-file db.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME
  showOutputs ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db
else
  # なかったら作成する
  aws cloudformation create-stack \
    --template-body file://db.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME \
    ParameterKey=DatabaseName,ParameterValue=DatabaseName \
    ParameterKey=DatabaseUser,ParameterValue=DatabaseUser \
    ParameterKey=DatabasePassword,ParameterValue=DatabasePassword
  showOutputs ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db
fi


#----------------------------------------------------------
#  api depends on db vpc sg
#----------------------------------------------------------

aws cloudformation package \
  --template-file ./api/template.yml \
  --s3-bucket $CLOUDFORMATION_TEMPLATE_BUCKET \
  --output-template-file ./api/output.yml \
  --profile $PROFILE
if test `isALreadyExistStack ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}` -ne 0;then
  # すでに存在するものへの変更
  aws cloudformation deploy \
    --template-file ${PWD}/api/output.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME \
    ServiceName=$SERVICE_NAME
    KeyPairName=$KEY_PAIR_NAME
  showOutputs residential-map-api
else
  # なかったら作成する
  aws cloudformation create-stack \
    --template-body file://api/output.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME \
    ParameterKey=AppS3Bucket,ParameterValue=$APP_S3_BUCKET \
    ParameterKey=AppS3Key,ParameterValue=$APP_S3_KEY \
    ParameterKey=ServiceName,ParameterValue=$SERVICE_NAME \
    ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME \
    ParameterKey=LoadBalancerDomainName,ParameterValue=${SERVICE_NAME}.${PRIVATE_DOMAIN_NAME} \
    ParameterKey=DatabaseName,ParameterValue=DatabaseName \
    ParameterKey=DatabaseUser,ParameterValue=DatabaseUser \
    ParameterKey=DatabasePassword,ParameterValue=DatabasePassword \
    ParameterKey=GitHubToken,ParameterValue=GitHubToken
  showOutputs ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}
fi
