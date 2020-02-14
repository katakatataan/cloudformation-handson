# 変更しても良い:自分の任意のプロジェクト名に変更
export PROJECT_NAME=cloudformation-handson
# 要変更: 自分で作成したec2 keypair名に変更
export KEY_PAIR_NAME=cloudformation-handson-matsuyay
# 変更しても良い: ただしdevかprod しか選択できない。
export ENVIORNMENT_NAME=dev
# aws configure --profile プロファイル名 のプロファイル名に指定したものに変更
export PROFILE=cloudhandson
# 要変更:s3 は全世界で一意のかぶらないものに変更
export APP_S3_BUCKET=app-s3-bucket-cloudformation-hands-on-api
# 変更しない: elasticbeanstalk の一番初めの起動に使われる静的ファイルが格納されてる。
export APP_S3_KEY=sample.zip
# 要変更:s3 は全世界で一意のかぶらないものに変更
export CODEPIPELINE_ARTIFACT_S3_BACKET_NAME=cloudformationhandson-codepipeline
# 要変更:s3 は全世界で一意のかぶらないものに変更
export CLOUDFORMATION_TEMPLATE_S3_BUCKET=yyyyyyy-cloudformation-hands-on-resource
# 変更しても良い: apiのstack名と関連するリソースが書き換わる。プライベートDNSも変わる。
export SERVICE_NAME=api
# 変更してもよい: privateなdomain名が書き換わる。今回はapiとdbのdomainが影響をうける
export PRIVATE_DOMAIN_NAME=private-cloudformation-handson.com
# 変更してもよい:ただ形式は {任意のsubdomain}.${PRIVATE_DOMAIN_NAME}の制約がある。
export DB_PRIVATE_DOMAIN_NAME=db.${PRIVATE_DOMAIN_NAME}
# 変更してもよい: 擬似的なpublicドメイン。ちゃんとしたものにするにはdomainをregistryから購入してawsのname serverを参照。
export DOMAIN_NAME=public-cloudformation-handson.com
