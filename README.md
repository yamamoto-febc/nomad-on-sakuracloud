# nomad-on-sakuracloud

参考記事：[Qiita:Nomad/Consul/Nginxでスケールアウト出来るコンテナホスティング環境 on さくらのクラウド](http://qiita.com/items/fa4b3dca54dfebb36973)

# 概要

さくらのクラウド上に以下の環境を構築します。

  - [Nomad](https://www.nomadproject.io)
  - [Consul](https://www.consul.io)
  - [ConsulTemplate](https://github.com/hashicorp/consul-template)
  - [Nginx](http://nginx.org)

![Nomad on さくらのクラウド概要](images/overview.jpg "Nomad on さくらのクラウド概要")

[Nomad](https://www.nomadproject.io)でジョブを投入することで、
Nginxのリバースプロキシ設定が自動で行われます。
これにより、nomadで起動したDockerコンテナの(自動割り当てされた)ポート番号を意識することなく
サービス提供が行えるようになります。

また、必要に応じて各役割のマシンをスケールアウトすることもできます。
Nomadのジョブ投入をCIに組み込むなど活用方法はいろいろです。


## 内部動作

Nomadでジョブを実行すると以下のような処理が行われます。

  - nomadサーバーがエージェントへジョブ割り振り
  - nomadエージェントがジョブ実施
  - nomadエージェントで自動割り当てされたポートをConsulに登録
  - ConsulTemplateでNginxのコンフィグファイルを生成、再読み込み(エンドポイント)

例えば、対象ドメインを`nomad.example.com`、サービス名を`apache`とした場合、
Nginxにて`http://apache.nomad.example.com/`というURLでアクセスすると
nomadエージェントで実行されているジョブへリバースプロキシされます。
また、nomadエージェントのグローバルIP/ポートを直接指定することでもアクセス可能です。


# 使い方

### 準備

以下を準備しておきます。

  - Terraform
  - Terraform for さくらのクラウド
  - さくらのクラウド APIキー
  - SSH用キーペア

[こちら](http://qiita.com/yamamoto-febc/items/ae92cd258cf040957487#セットアップ)の手順が参考に準備してください。
[Terraform for さくらのクラウド スタートガイド:セットアップ](http://qiita.com/yamamoto-febc/items/ae92cd258cf040957487#セットアップ)

APIキーは以下のように環境変数に設定しておいてください。

```bash:APIキー設定
$ export SAKURACLOUD_ACCESS_TOKEN = [取得したAPIキー(トークン)]
$ export SAKURACLOUD_ACCESS_TOKEN_SECRET = [取得したAPIキー(シークレット)]
```


SSH用キーペアについては以下コマンドで生成できます。

```bash:キーペア生成
$ ssh-keygen -C "" -f keys/id_rsa
```

### 準備(設定ファイル取得/対象ドメインの設定)

当リポジトリをチェックアウトしておきます。

```bash
$ git clone https://github.com/yamamoto-febc/nomad-on-sakuracloud.git
$ cd nomad-on-sakuracloud
```

各種設定項目は`variables.tf`ファイルに記載されています。
上記ファイルを編集し、先頭付近の`target_domain`の定義を以下のように編集します。
`YOUR_DOMAIN`の部分を任意のドメインに置き換えてください。
(編集しなかった場合、terraformコマンド実行時に入力することになります)
ここで指定したドメインのサブドメインが自動で割り当てられます。

```variables.tf
variable "target_domain" { 
    defautl = "YOUR_DOMAIN"
}
```


その他の項目は必要に応じて編集してください。


### 構築

#### Terraformでの構築

Terraformでインフラの構築を行います。

```bash:Terraform実行
# Terraformで構築される内容の確認
$ terraform plan

# 構築
$ terraform apply
```


#### ワイルドカードDNSの登録

構築できたら対象ドメインのDNSレコードへフロントエンドのグローバルIPを設定します。
グローバルIPはさくらのクラウド側で自動割り当てされます。
以下コマンドでグローバルIPアドレスが確認できます。

```bash:フロントエンドのグローバルIP確認
$ terraform output front_global_ip
```

確認したIPアドレスを対象ドメインのサブドメインにワイルドカード登録しておきましょう。
さくらのクラウドの場合は以下のような感じで登録しておきます。

![さくらのクラウドDNSでのワイルドカード登録例](images/dns_example.jpg "さくらのクラウドDNSでのワイルドカード登録例")

もちろん`Terraform for さくらのクラウド`からさくらのDNSヘ登録してもOKです。

## Nomadでのジョブ実行

### 1) NomadサーバーへSSH接続
SSHでNomadサーバーを実行しているマシンにログインしジョブ投入します。
`terraform apply`を実行するとSSH接続用のヘルパースクリプトが`ssh/`ディレクトリ配下に生成されているため、
それを使ってSSH接続を行います。

```bash:nomadサーバーへのSSH接続
$ ssh/servers01.sh
```

### 2) ジョブ定義

サンプルジョブが`~/nomad_sample`に格納されています。
これをコピーしてジョブ定義を行います。
(もちろん自分でジョブ定義を記載しても構いません)

```bash:ジョブ定義
$ cp ~/nomad_sample/apache.nomad ./
```

サンプルではDockerHubからApacheイメージを取得して実行しています。
必要に応じてジョブ定義ファイルを編集してみてください。

サービス定義(job->group->task配下)が規約に沿って行われていれば
自動でフロントエンドにリバースプロキシ設定が行われます。
（サービス定義の規約は[こちら](#nomadサービス定義)を参照）

### 3) ジョブ実行

作成したジョブ定義ファイルを使ってジョブを実行してみます。

```bash:nomadジョブ実行
$ nomad run apache.nomad
```

ジョブの稼働状況の確認は以下コマンドなどで行います。

  - `nomad status` : 実行されているジョブ一覧表示
  - `nomad status [ジョブ名]` : 実行されているジョブの詳細確認

あとは`http://[定義したサービス名].[対象ドメイン]/`にブラウザなどアクセスすれば表示されるはずです。
例：対象サービス名が`service01`、対象ドメイン名が`nomad.fe-bc.net`の場合、`http://servic01.nomad.fe-bc.net`にアクセスすればOK

# リファレンス

## インフラ定義(variables.tf)

Terraformでのインフラ定義設定は`variables.tf`ファイルに記載されています。

スペックなど必要に応じて変更してください。
また、Nomadサーバー、Nomadエージェント、フロントエンド(Nginx)とも台数を増やすことも可能です。
台数を増やす場合、割りあてるプライベートIPアドレスも定義してください。
プライベートIPアドレスはカンマ区切りで指定します。以下例を参照ください。

#### 1台の例

```
# マシン台数/各マシンのIP
variable "servers_count" {default = "1"}
variable servers_private_ip_list{
  default = {
    consul = "192.168.10.11"
    nomad  = "192.168.20.11"
  }
}

```

#### 3台の例

```
# マシン台数/各マシンのIP
variable "servers_count" {default = "3"}
variable servers_private_ip_list{
  default = {
    consul = "192.168.10.11,192.168.10.12,192.168.10.13"
    nomad  = "192.168.20.11,192.168.20.12,192.168.20.13"
  }
}

```


## nomadサービス定義

通常の[nomadでのサービス定義](https://www.nomadproject.io/docs/jobspec/servicediscovery.html)に加え、以下2項目が重要です。

### `name`

サービス名です。この値でエンドポイントを割り当てます。
例：サービス名が`service01`、対象ドメイン名が`nomad.fe-bc.net`の場合、エンドポイントは`http://servic01.nomad.fe-bc.net`となる。

同名のサービスがすでに定義されている場合、フロントエンドNginxにてラウンドロビンされます。


### `tags`

サービス定義部分で`nomad-worker`というタグを付与してください。
このタグが付与されたサービスのみフロントエンドNginxへのリバースプロキシ設定反映の対象となります。

### 記載例

```定義例
service {
	name = "service01"      # ここの名前がサービス名となります。
	tags = ["nomad-worker"] # !!ここがポイント!!
	port = "http"
	check {
		name = "alive"
		type = "tcp"
		interval = "10s"
		timeout = "2s"
	}
}

```

