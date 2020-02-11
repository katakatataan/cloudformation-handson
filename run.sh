#!/bin/sh
# set -x
# yes/noで応答
PROJECT_NAME=cloudformation-handson
KEY_PAIR_NAME=cloudformation-handson
ENVIORNMENT_NAME=dev
PROFILE=cloudformation-handson
# かぶらないもの
APP_S3_BUCKET=cloudformation-hands-on-api
APP_S3_KEY=sample.zip
SERVICE_NAME=api
PRIVATE_DOMAIN_NAME=private-cloudformation-handson.com
DOMAIN_NAME=public-cloudformation-handson.com
# かぶらないもの
CLOUDFORMATION_TEMPLATE_BUCKET=cloudformation-hands-on-resource
if aws s3 ls "s3://$CLOUDFORMATION_TEMPLATE_BUCKET" 2>&1 | grep -q 'An error occurred'; then
  aws s3api create-bucket \
    --bucket $CLOUDFORMATION_TEMPLATE_BUCKET \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --create-bucket-configuration LocationConstraint=ap-northeast-1
else
        echo "bucket exists${CLOUDFORMATION_TEMPLATE_BUCKET}"
fi

if aws s3 ls "s3://$APP_S3_BUCKET" 2>&1 | grep -q 'An error occurred'; then
  aws s3api create-bucket \
    --bucket $APP_S3_BUCKET \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --create-bucket-configuration LocationConstraint=ap-northeast-1
  aws s3api wait bucket-exists \
    --bucket $APP_S3_BUCKET
  aws s3 cp ${APP_S3_KEY} s3://${APP_S3_BUCKET}/ \
    --profile=$PROFILE \
    --region ap-northeast-1
else
  echo "bucket exists${APP_S3_BUCKET}"
  aws s3 cp ${APP_S3_KEY} s3://${APP_S3_BUCKET}/ \
    --profile=$PROFILE \
    --region ap-northeast-1
fi


#----------------------------------------------------------
#  vpc
#----------------------------------------------------------
if aws cloudformation describe-stacks --profile $PROFILE --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc ; then
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
  aws cloudformation wait stack-create-complete \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc
fi


#----------------------------------------------------------
#  dns depends on vpc
#----------------------------------------------------------
if aws cloudformation describe-stacks --profile $PROFILE --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns ; then
  # すでに存在するものへの変更
  aws cloudformation deploy \
    --template-file route53.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME
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
  aws cloudformation wait stack-create-complete \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns
fi

#----------------------------------------------------------
#  db dependds on db
#----------------------------------------------------------
if aws cloudformation describe-stacks --profile $PROFILE --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db ; then
  # すでに存在するものへの変更
  aws cloudformation deploy \
    --template-file db.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME
else
  # なかったら作成する
  aws cloudformation create-stack \
    --template-body file://db.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=DatabaseName,ParameterValue=DatabaseName \
    ParameterKey=DatabaseUser,ParameterValue=DatabaseUser \
    ParameterKey=DatabasePassword,ParameterValue=DatabasePassword \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME
  aws cloudformation wait stack-create-complete \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db
fi


#----------------------------------------------------------
#  api depends on db vpc sg
#----------------------------------------------------------

aws cloudformation package \
  --template-file ./api/template.yml \
  --s3-bucket $CLOUDFORMATION_TEMPLATE_BUCKET \
  --output-template-file ./api/output.yml \
  --profile $PROFILE
if aws cloudformation describe-stacks --profile $PROFILE --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} ; then
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
  aws cloudformation wait stack-create-complete \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}
fi
