#!/usr/bin/env bash
# set -x

source env.sh

export PROJECT_NAME
export KEY_PAIR_NAME
export ENVIORNMENT_NAME
export PROFILE
export APP_S3_BUCKET
export APP_S3_KEY
export SERVICE_NAME
export PRIVATE_DOMAIN_NAME
export DOMAIN_NAME
export DB_PRIVATE_DOMAIN_NAME
export CLOUDFORMATION_TEMPLATE_S3_BUCKET
export CODEPIPELINE_ARTIFACT_S3_BACKET_NAME
databaseName=$(aws ssm get-parameters --names "DatabaseName" --profile $PROFILE --region ap-northeast-1 | jq -r ".Parameters[0].Name")
if [ ! $databaseName = "DatabaseName" ]; then
  echo "Parameter Store: DatabaseName Not Exist"
  exit 1
fi
databasePassword=$(aws ssm get-parameters --names "DatabasePassword" --profile $PROFILE --region ap-northeast-1 | jq -r ".Parameters[0].Name")
if [ ! $databasePassword = "DatabasePassword" ]; then
  echo "Parameter Store: DatabasePassword Not Exist"
  exit 1
fi
databaseUser=$(aws ssm get-parameters --names "DatabaseUser" --profile $PROFILE --region ap-northeast-1 | jq -r ".Parameters[0].Name")
if [ ! $databaseUser = "DatabaseUser" ]; then
  echo "Parameter Store: DatabaseUser Not Exist"
  exit 1
fi
githubToken=$(aws ssm get-parameters --names "GitHubToken" --profile $PROFILE --region ap-northeast-1 | jq -r ".Parameters[0].Name")
if [ ! $githubToken = "GitHubToken" ]; then
  echo "Parameter Store: GitHubToken Not Exist"
  exit 1
fi
echo '------------------------------------------------------------------------------------------'
echo 'create s3 bucket for cloudformation yml'
echo '------------------------------------------------------------------------------------------'
if aws s3 ls "s3://$CLOUDFORMATION_TEMPLATE_S3_BUCKET" --profile $PROFILE --region ap-northeast-1 2>&1 | grep -q 'An error occurred'; then
  echo "bucketName: $CLOUDFORMATION_TEMPLATE_S3_BUCKET"
  aws s3api create-bucket \
    --bucket $CLOUDFORMATION_TEMPLATE_S3_BUCKET \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --create-bucket-configuration LocationConstraint=ap-northeast-1
else
        echo "bucket exists: ${CLOUDFORMATION_TEMPLATE_S3_BUCKET}"
fi

echo '------------------------------------------------------------------------------------------'
echo 'create s3 bucket for elasticbeanstalk app source yml'
echo '------------------------------------------------------------------------------------------'
if aws s3 ls "s3://$APP_S3_BUCKET" --profile $PROFILE --region ap-northeast-1 2>&1 | grep -q 'An error occurred'; then
  echo "bucketName: $APP_S3_BUCKET"
  aws s3api create-bucket \
    --bucket $APP_S3_BUCKET \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --create-bucket-configuration LocationConstraint=ap-northeast-1
  aws s3api wait bucket-exists \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --bucket $APP_S3_BUCKET
  aws s3 cp ${APP_S3_KEY} s3://${APP_S3_BUCKET}/ \
    --profile $PROFILE \
    --region ap-northeast-1
else
  echo "bucket exists: ${APP_S3_BUCKET}"
  aws s3 cp ${APP_S3_KEY} s3://${APP_S3_BUCKET}/ \
    --profile $PROFILE \
    --region ap-northeast-1
fi

#----------------------------------------------------------
#  vpc
#----------------------------------------------------------
echo '------------------------------------------------------------------------------------------'
echo 'create vpc'
echo '------------------------------------------------------------------------------------------'
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc 2>&1 | grep -q 'An error occurred'; then
  # すでに存在するものへの変更
  echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc is already exist"
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc| jq -r ".Stacks[0].StackStatus")
  echo "stackStatus: $stackStatus"
  if [ $stackStatus = "CREATE_IN_PROGRESS" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc wait for create complete"
    aws cloudformation wait stack-create-complete \
      --profile $PROFILE \
      --region ap-northeast-1 \
      --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc
  elif [ $stackStatus = "ROLLBACK_IN_PROGRESS" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_FAILED" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_COMPLETE" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc shoud delete"
    exit 1
  fi
  aws cloudformation deploy \
    --template-file vpc.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME \
    KeyPairName=$KEY_PAIR_NAME
else
  # なかったら作成する
  echo "create stack: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc"
  aws cloudformation create-stack \
    --template-body file://vpc.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc \
    --capabilities CAPABILITY_IAM \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME \
    ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME
  aws cloudformation wait stack-create-complete \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-vpc
fi


#----------------------------------------------------------
#  dns depends on vpc
#----------------------------------------------------------
echo '------------------------------------------------------------------------------------------'
echo 'create dns'
echo '------------------------------------------------------------------------------------------'
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns 2>&1 | grep -q 'An error occurred'; then
  # すでに存在するものへの変更
  echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns is already exist"
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns | jq -r ".Stacks[0].StackStatus")
  echo "stackStatus: $stackStatus"
  if [ $stackStatus = "CREATE_IN_PROGRESS" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns wait for create complete"
    aws cloudformation wait stack-create-complete \
      --profile $PROFILE \
      --region ap-northeast-1 \
      --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns
  elif [ $stackStatus = "ROLLBACK_IN_PROGRESS" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_FAILED" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_COMPLETE" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns shoud delete"
    exit 1
  fi
  aws cloudformation deploy \
    --template-file route53.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns \
    --capabilities CAPABILITY_IAM \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME
else
  # なかったら作成する
  echo "create stack: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns"
  aws cloudformation create-stack \
    --template-body file://route53.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns \
    --capabilities CAPABILITY_IAM \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=DomainName,ParameterValue=${DOMAIN_NAME}. \
    ParameterKey=PrivateDomainName,ParameterValue=${PRIVATE_DOMAIN_NAME}. \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME
  aws cloudformation wait stack-create-complete \
    --region ap-northeast-1 \
    --profile $PROFILE \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-dns
fi

#----------------------------------------------------------
#  db dependds on db
#----------------------------------------------------------
echo '------------------------------------------------------------------------------------------'
echo 'create db'
echo '------------------------------------------------------------------------------------------'
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db 2>&1 | grep -q 'An error occurred'; then
  # すでに存在するものへの変更
  echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db already exist"
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db| jq -r ".Stacks[0].StackStatus")
  echo "stackStatus: $stackStatus"
  if [ $stackStatus = "CREATE_IN_PROGRESS" ]; then
    echo "wait for create complete"
    aws cloudformation wait stack-create-complete \
      --profile $PROFILE \
      --region ap-northeast-1 \
      --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db
  elif [ $stackStatus = "ROLLBACK_IN_PROGRESS" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_FAILED" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_COMPLETE" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db shoud delete"
    exit 1
  fi
  aws cloudformation deploy \
    --template-file db.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db \
    --region ap-northeast-1 \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME
else
  # なかったら作成する
  echo "create stack: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db"
  aws cloudformation create-stack \
    --template-body file://db.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db \
    --region ap-northeast-1 \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameters \
    ParameterKey=DBDomainName,ParameterValue=$DB_PRIVATE_DOMAIN_NAME \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=DatabaseName,ParameterValue=DatabaseName \
    ParameterKey=DatabaseUser,ParameterValue=DatabaseUser \
    ParameterKey=DatabasePassword,ParameterValue=DatabasePassword \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME
  aws cloudformation wait stack-create-complete \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-db
fi


#----------------------------------------------------------
#  api depends on db vpc sg
#----------------------------------------------------------

echo '------------------------------------------------------------------------------------------'
echo 'create api with codepipline deploy automation'
echo '------------------------------------------------------------------------------------------'
aws cloudformation package \
  --template-file ./api/template.yml \
  --s3-bucket $CLOUDFORMATION_TEMPLATE_S3_BUCKET \
  --region ap-northeast-1 \
  --output-template-file ./api/output.yml \
  --profile $PROFILE
if ! aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} 2>&1 | grep -q 'An error occurred'; then
  # すでに存在するものへの変更
  echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} already exist"
  stackStatus=$(aws cloudformation describe-stacks --profile $PROFILE --region ap-northeast-1 --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}| jq -r ".Stacks[0].StackStatus")
  if [ $stackStatus = "CREATE_IN_PROGRESS" ]; then
    echo "wait for compelte"
    aws cloudformation wait stack-create-complete \
      --profile $PROFILE \
      --region ap-northeast-1 \
      --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}
  elif [ $stackStatus = "ROLLBACK_IN_PROGRESS" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_FAILED" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} shoud delete"
    exit 1
  elif [ $stackStatus = "ROLLBACK_COMPLETE" ]; then
    echo "stack-name: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} shoud delete"
    exit 1
  fi
  aws cloudformation deploy \
    --template-file ${PWD}/api/output.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --parameter-overrides \
    ProjectName=$PROJECT_NAME \
    EnvironmentName=$ENVIORNMENT_NAME \
    ServiceName=$SERVICE_NAME
    KeyPairName=$KEY_PAIR_NAME
else
  # なかったら作成する
  echo "create stack: ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}"
  aws cloudformation create-stack \
    --template-body file://api/output.yml \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME} \
    --region ap-northeast-1 \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --parameters \
    ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
    ParameterKey=EnvironmentName,ParameterValue=$ENVIORNMENT_NAME \
    ParameterKey=AppS3Bucket,ParameterValue=$APP_S3_BUCKET \
    ParameterKey=ArtifactBucketName,ParameterValue=$CODEPIPELINE_ARTIFACT_S3_BACKET_NAME \
    ParameterKey=AppS3Key,ParameterValue=$APP_S3_KEY \
    ParameterKey=ServiceName,ParameterValue=$SERVICE_NAME \
    ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME \
    ParameterKey=LoadBalancerDomainName,ParameterValue=${SERVICE_NAME}.${PRIVATE_DOMAIN_NAME} \
    ParameterKey=DatabaseName,ParameterValue=DatabaseName \
    ParameterKey=DatabaseUser,ParameterValue=DatabaseUser \
    ParameterKey=DatabasePassword,ParameterValue=DatabasePassword \
    ParameterKey=GitHubToken,ParameterValue=GitHubToken
  aws cloudformation wait stack-create-complete \
    --profile $PROFILE \
    --region ap-northeast-1 \
    --stack-name ${PROJECT_NAME}-${ENVIORNMENT_NAME}-${SERVICE_NAME}
fi
