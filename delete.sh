#!/usr/bin/env bash
# set -x
source env.sh

export PROJECT_NAME
export ENVIORNMENT_NAME
export PROFILE
export APP_S3_BUCKET
export SERVICE_NAME
export CLOUDFORMATION_TEMPLATE_S3_BUCKET


echo '------------------------------------------------------------------------------------------'
echo 'delete s3 bucket for cloudformation yml'
echo '------------------------------------------------------------------------------------------'
if ! aws s3 ls "s3://$CLOUDFORMATION_TEMPLATE_S3_BUCKET" --profile $PROFILE --region ap-northeast-1 2>&1 | grep -q 'An error occurred'; then
  echo "bucketName: $CLOUDFORMATION_TEMPLATE_S3_BUCKET"
  aws s3 rb s3://$CLOUDFORMATION_TEMPLATE_S3_BUCKET \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --force
  aws s3api wait bucket-not-exists \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --bucket $CLOUDFORMATION_TEMPLATE_S3_BUCKET
fi

echo '------------------------------------------------------------------------------------------'
echo 'delete s3 bucket for elasticbeanstalk app source yml'
echo '------------------------------------------------------------------------------------------'
if aws s3 ls "s3://$APP_S3_BUCKET" --profile $PROFILE --region ap-northeast-1 2>&1 | grep -q 'An error occurred'; then
  aws s3 rb s3://$APP_S3_BUCKET \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --force
  aws s3api wait bucket-not-exists \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --bucket $APP_S3_BUCKET
fi

echo '------------------------------------------------------------------------------------------'
echo 'delete ecr bucket'
echo '------------------------------------------------------------------------------------------'
echo 'should delete ecr repository manually'
echo 'https://ap-northeast-1.console.aws.amazon.com/ecr/repositories?region=ap-northeast-1'

echo '------------------------------------------------------------------------------------------'
echo 'delete api stack'
echo '------------------------------------------------------------------------------------------'
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} 2>&1 | grep -q 'An error occurred'; then
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}| jq -r ".Stacks[0].StackStatus")
  echo "stackStatus: $stackStatus"
  echo "stackName: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} wait for delete"
  aws cloudformation delete-stack \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} \
    --region ap-northeast-1 \
    --profile $PROFILE
  aws cloudformation wait stack-delete-complete \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}
fi

echo '------------------------------------------------------------------------------------------'
echo 'delete db stack'
echo '------------------------------------------------------------------------------------------'
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db 2>&1 | grep -q 'An error occurred'; then
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db| jq -r ".Stacks[0].StackStatus")
  echo "stackStatus: $stackStatus"
  echo "stackName: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db wait for delete"
  aws cloudformation delete-stack \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db \
    --region ap-northeast-1 \
    --profile $PROFILE
  aws cloudformation wait stack-delete-complete \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db
fi

echo '------------------------------------------------------------------------------------------'
echo 'delete dns stack'
echo '------------------------------------------------------------------------------------------'
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns 2>&1 | grep -q 'An error occurred'; then
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns| jq -r ".Stacks[0].StackStatus")
  echo "stackStatus: $stackStatus"
  echo "stackName: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns wait for delete"
  aws cloudformation delete-stack \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns \
    --region ap-northeast-1 \
    --profile $PROFILE
  aws cloudformation wait stack-delete-complete \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns
fi

echo '------------------------------------------------------------------------------------------'
echo 'delete vpc stack'
echo '------------------------------------------------------------------------------------------'
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc 2>&1 | grep -q 'An error occurred'; then
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc| jq -r ".Stacks[0].StackStatus")
  echo "stackStatus: $stackStatus"
  echo "stackName: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc wait for delete"
  aws cloudformation delete-stack \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc \
    --region ap-northeast-1 \
    --profile $PROFILE
  aws cloudformation wait stack-delete-complete \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc
fi

