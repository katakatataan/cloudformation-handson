export PROJECT_NAME=cloudformation-handson
export KEY_PAIR_NAME=cloudformation-handson-matsuyay
export ENVIORNMENT_NAME=dev
export PROFILE=cloudhandson
# s3 は全世界で一意のかぶらないもの
export APP_S3_BUCKET=app-s3-bucket-cloudformation-hands-on-api
export APP_S3_KEY=sample.zip
export CODEPIPELINE_ARTIFACT_S3_BACKET_NAME=cloudformationhandson-codepipeline
export CLOUDFORMATION_TEMPLATE_S3_BUCKET=yyyyyyy-cloudformation-hands-on-resource

export SERVICE_NAME=api
export PRIVATE_DOMAIN_NAME=private-cloudformation-handson.com
export DB_PRIVATE_DOMAIN_NAME=db.${PRIVATE_DOMAIN_NAME}
export DOMAIN_NAME=public-cloudformation-handson.com
