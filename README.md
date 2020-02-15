## Overall

1. AWSアカウントの作成
2. AWSのIAM　Userの作成
3. Installnig aws cli
4. get aws api key
5. set aws api key to aws credentials
6. create ec2 key pair
7. create parameter store [GitHubToken, DatabaseUser, DatabaseName, DatabasePassword]
8. set your environment
9. run cloudformation
10. finish operation. delete cloudformation



## 1. AWSアカウントの作成
https://aws.amazon.com/jp/register-flow/

## 2. AWSのIAM Userの作成

[IAM 作成ドキュメント](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/id_users_create.html#id_users_create_api)

[IAM コンソール](https://console.aws.amazon.com/iam/home?#/users)

## 3. Installnig aws cli

動作確認できている aws-cliのversion

```
aws-cli/1.17.17 Python/3.8.1 Darwin/19.2.0 botocore/1.14.17
```

参考になりそうな記事
[brewでAWS CLIのインストール](https://qiita.com/okhrn/items/8da6b217d3b1fce63371)

## 4. IAM Userからアクセスキーとシークレットの取得

下記のリンクにアクセスして、アクセスキーの作成を押下してください。

※ 1IAMUserは2つまでしかキーの発行ができません。

https://console.aws.amazon.com/iam/home?#/users/{作成したIAMUser名}?section=security_credentials

表示された
```
アクセスキー
シークレットアクセスキー
```
をメモしてください。


## 5.  awsのクレデンシャルのセット

下記のコマンドを実行してください。

```
aws configure --profile {任意のprofile名}
```

いくつか入力を求められるので、アクセスキーとシークレットアクセスキーを記載してください


```
$ aws configure --profile {任意のprofile名}
AWS Access Key ID [None]: XXXXXXXXXXXXXXXX
AWS Secret Access Key [None]: XXXXXXXXXXXXXXXX
Default region name [None]: ap-northeast-1
Default output format [None]: json
```

## 6. aws ec2 キーペアを作成してください。

ec2キーペアはbastionとebの内部のec2インスタンスに使用します。

下記のリンクにアクセスして作成してください。

https://ap-northeast-1.console.aws.amazon.com/ec2/v2/home?region=ap-northeast-1#KeyPairs:

## 7. パラメータストアの理解も含めて手動でparameter storeを作成します。

GiHubToken, DatabaseName, DatabaseUser, DatabasePassword の4つのパラメータを作成します。


GithubTokenに関しては、GitHubにアクセスして、Generate new tokenを押して作成してください。

下記のリンクにアクセスして作成してください。

※　すでに取得している人はそちらを使用してください。

権限は今回のhandsonではpublic repositoryのcloneのみを行いますので、

public_repoのみで大丈夫です。

[GitHub Token取得ページ](https://github.com/settings/tokens)

https://ap-northeast-1.console.aws.amazon.com/systems-manager/parameters?region=ap-northeast-1

手順は下記の通りです。

1. パラメータの作成
2. 名前:[GitHubToken]
3. 利用枠:[標準]
4. タイプ:文字列
5. タイプ: GitHubの個人のアクセストークン

1. パラメータの作成
2. 名前:[DatabaseName]
3. 利用枠:[標準]
4. タイプ:文字列
5. タイプ:任意の名前のデータベース名(RDSに使用されます。)

1. パラメータの作成
2. 名前:[DatabaseUser]
3. 利用枠:[標準]
4. タイプ:文字列
5. タイプ:任意の名前のデータベース名(RDSに使用されます。)

1. パラメータの作成
2. 名前:[DatabasePassword]
3. 利用枠:[標準]
4. タイプ:文字列[7文字以上]
5. タイプ:任意の名前のデータベース名(RDSに使用されます。)



## 8. 環境変数のセット

上記までの作業で得られた情報も踏まえて環境変数をセットしてください。

説明はコメントで記載しています

```shellscript:env.sh
# 変更しても良い:自分の任意のプロジェクト名に変更
export PROJECT_NAME=cloudformation-handson
# 要変更: 自分で作成したec2 keypair名に変更
export KEY_PAIR_NAME=cloudformation-handson
# 変更しても良い: ただしdevかprod しか選択できない。
export ENVIORNMENT_NAME=dev
# 要変更: aws configure --profile {任意のprofile名} の{任意のprofile名}に指定したものに変更
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
```


## 9. cloudformationで今回のhandson環境を作成します。

下記のコマンドを実行して、スタックが作成されるまで待ちます。

かなり時間がかかります。

注意点

※ スタックのステータスがCREATE_COMPELTEとCREATE_IN_PROGRESS以外の場合はスタックをaws コンソールから手動で削除してやり直してみてください。

[aws cloudformation console](https://ap-northeast-1.console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks?filteringText=&filteringStatus=active&viewNested=true&hideStacks=false
)

※ 途中でctrl+c でストップしても、cloudformationのステータスがCREATE_IN_PROGRESS, CREATE_COMPELTEなら再度 ./deploy.sh をやり直すだけです。

※ 一応冪等性をそこそこ担保して作ってるので、何回再実行しても複数リソースは作られません。

```
chmod +x deploy.sh
./deploy.sh
```


## 10. 環境の削除

ECRは手動で消す以外にうまい方法がないのでまず元にECRを手動で削除します。

https://ap-northeast-1.console.aws.amazon.com/ecr/repositories?region=ap-northeast-1

ecr名: ${PROJECT_NAME}-${SERVICE_NAME}-${ENVIORNMENT_NAME}

次に下記のdelete.shを実行してスタックが削除されるまで待ちます。

```
chomod +x delete.sh
./delete.sh
```
