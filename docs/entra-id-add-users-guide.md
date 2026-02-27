# Microsoft Entra ID ユーザ追加ガイド（ポータル以外の方法）

Azure ポータル画面を使わずに Microsoft Entra ID（旧 Azure AD）にユーザを追加する方法をまとめます。ハンズオン環境の一括構築時など、多数のユーザを効率的に作成する場合に活用してください。

> **前提条件**: いずれの方法でも、操作するアカウントに **ユーザー管理者** ロール以上の権限が必要です。

---

## 目次

1. [Azure CLI](#1-azure-cli)
2. [Azure PowerShell（Microsoft Graph モジュール）](#2-azure-powershellmicrosoft-graph-モジュール)
3. [Microsoft Graph REST API](#3-microsoft-graph-rest-api)
4. [CSV 一括作成スクリプト](#4-csv-一括作成スクリプト)
5. [Terraform / Bicep（IaC）](#5-terraform--bicepiac)

---

## 1. Azure CLI

Azure CLI の `az ad user create` コマンドでユーザを作成できます。

### インストール確認

```bash
az version
```

### 単一ユーザの作成

```bash
az ad user create \
  --display-name "Taro Yamada" \
  --user-principal-name taro@contoso.onmicrosoft.com \
  --password "P@ssw0rd1234!" \
  --force-change-password-next-sign-in true
```

### 主なパラメータ

| パラメータ | 説明 |
|---|---|
| `--display-name` | 表示名 |
| `--user-principal-name` | サインインに使う UPN（`user@domain`） |
| `--password` | 初期パスワード |
| `--force-change-password-next-sign-in` | 初回サインイン時にパスワード変更を強制（`true` / `false`） |
| `--mail-nickname` | メールエイリアス（省略時は UPN のローカル部分が使用される） |

### 作成したユーザの確認

```bash
az ad user show --id taro@contoso.onmicrosoft.com --query '{displayName:displayName, upn:userPrincipalName, id:id}' -o table
```

### 複数ユーザの一括作成（シェルスクリプト）

```bash
#!/bin/bash
DOMAIN="contoso.onmicrosoft.com"

for i in $(seq -w 1 10); do
  UPN="user${i}@${DOMAIN}"
  DISPLAY_NAME="User ${i}"
  PASSWORD="P@ssw0rd${i}!"

  echo "Creating ${UPN} ..."
  az ad user create \
    --display-name "${DISPLAY_NAME}" \
    --user-principal-name "${UPN}" \
    --password "${PASSWORD}" \
    --force-change-password-next-sign-in true \
    -o none

  if [ $? -eq 0 ]; then
    echo "  ✅ ${UPN} created successfully"
  else
    echo "  ❌ ${UPN} failed"
  fi
done
```

---

## 2. Azure PowerShell（Microsoft Graph モジュール）

PowerShell の **Microsoft.Graph** モジュールを使用してユーザを作成します。

### モジュールのインストール

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### 接続

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"
```

### 単一ユーザの作成

```powershell
$passwordProfile = @{
    Password                      = "P@ssw0rd1234!"
    ForceChangePasswordNextSignIn = $true
}

New-MgUser -DisplayName "Taro Yamada" `
           -UserPrincipalName "taro@contoso.onmicrosoft.com" `
           -MailNickname "taro" `
           -AccountEnabled `
           -PasswordProfile $passwordProfile
```

### 複数ユーザの一括作成

```powershell
$domain = "contoso.onmicrosoft.com"

1..10 | ForEach-Object {
    $num = $_.ToString("000")
    $upn = "user${num}@${domain}"
    $displayName = "User ${num}"

    $passwordProfile = @{
        Password                      = "P@ssw0rd${num}!"
        ForceChangePasswordNextSignIn = $true
    }

    try {
        New-MgUser -DisplayName $displayName `
                   -UserPrincipalName $upn `
                   -MailNickname "user${num}" `
                   -AccountEnabled `
                   -PasswordProfile $passwordProfile `
                   -ErrorAction Stop
        Write-Host "✅ $upn created" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ $upn failed: $_" -ForegroundColor Red
    }
}
```

---

## 3. Microsoft Graph REST API

HTTP リクエストで直接 Microsoft Graph API を呼び出してユーザを作成します。自動化パイプラインや他言語からの統合に適しています。

### エンドポイント

```
POST https://graph.microsoft.com/v1.0/users
```

### リクエスト例（curl）

```bash
# アクセストークンを取得（Azure CLI 経由）
TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)

# ユーザ作成
curl -X POST "https://graph.microsoft.com/v1.0/users" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "accountEnabled": true,
    "displayName": "Taro Yamada",
    "mailNickname": "taro",
    "userPrincipalName": "taro@contoso.onmicrosoft.com",
    "passwordProfile": {
      "forceChangePasswordNextSignIn": true,
      "password": "P@ssw0rd1234!"
    }
  }'
```

### 一括作成例（JSON Lines ファイル + curl）

```bash
# Azure CLI でトークンを取得し、curl で Graph API を呼ぶのが最もシンプルです
TOKEN=$(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)

# 一括作成（JSON Lines ファイルから）
while IFS= read -r line; do
  curl -s -X POST "https://graph.microsoft.com/v1.0/users" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${line}"
done < users.jsonl
```

### レスポンス例（成功時: 201 Created）

```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "Taro Yamada",
  "userPrincipalName": "taro@contoso.onmicrosoft.com",
  "mail": null
}
```

---

## 4. CSV 一括作成スクリプト

ハンズオン環境で大量のユーザを一括作成する場合の実践的なスクリプトです。

### users.csv の準備

```csv
displayName,userPrincipalName,password
User 001,user001@contoso.onmicrosoft.com,P@ssw0rd001!
User 002,user002@contoso.onmicrosoft.com,P@ssw0rd002!
User 003,user003@contoso.onmicrosoft.com,P@ssw0rd003!
```

### Bash + Azure CLI で一括作成

```bash
#!/bin/bash
set -euo pipefail

CSV_FILE="users.csv"
LOG_FILE="create-users-$(date +%Y%m%d-%H%M%S).log"

echo "=== Entra ID ユーザ一括作成 ===" | tee "${LOG_FILE}"
echo "開始: $(date)" | tee -a "${LOG_FILE}"

# ヘッダ行をスキップして読み込み
tail -n +2 "${CSV_FILE}" | while IFS=',' read -r displayName upn password; do
  echo -n "Creating ${upn} ... " | tee -a "${LOG_FILE}"

  if az ad user create \
    --display-name "${displayName}" \
    --user-principal-name "${upn}" \
    --password "${password}" \
    --force-change-password-next-sign-in true \
    -o none 2>>"${LOG_FILE}"; then
    echo "✅ OK" | tee -a "${LOG_FILE}"
  else
    echo "❌ FAILED" | tee -a "${LOG_FILE}"
  fi
done

echo "完了: $(date)" | tee -a "${LOG_FILE}"
echo "ログ: ${LOG_FILE}"
```

### PowerShell + Microsoft Graph で一括作成

```powershell
# CSV 読み込み → Microsoft Graph で一括作成
Connect-MgGraph -Scopes "User.ReadWrite.All"

$users = Import-Csv -Path "users.csv"

foreach ($user in $users) {
    $passwordProfile = @{
        Password                      = $user.password
        ForceChangePasswordNextSignIn = $true
    }

    $mailNickname = ($user.userPrincipalName -split "@")[0]

    try {
        New-MgUser -DisplayName $user.displayName `
                   -UserPrincipalName $user.userPrincipalName `
                   -MailNickname $mailNickname `
                   -AccountEnabled `
                   -PasswordProfile $passwordProfile `
                   -ErrorAction Stop
        Write-Host "✅ $($user.userPrincipalName) created" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ $($user.userPrincipalName) failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Disconnect-MgGraph
```

---

## 5. Terraform / Bicep（IaC）

Infrastructure as Code でユーザ管理を行う方法です。

### Terraform（AzureAD プロバイダー）

```hcl
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

variable "users" {
  type = map(object({
    display_name = string
    password     = string
  }))
  default = {
    "user001" = { display_name = "User 001", password = "P@ssw0rd001!" }
    "user002" = { display_name = "User 002", password = "P@ssw0rd002!" }
    "user003" = { display_name = "User 003", password = "P@ssw0rd003!" }
  }
}

data "azuread_domains" "default" {
  only_initial = true
}

resource "azuread_user" "users" {
  for_each = var.users

  display_name        = each.value.display_name
  user_principal_name = "${each.key}@${data.azuread_domains.default.domains[0].domain_name}"
  mail_nickname       = each.key
  password            = each.value.password
  account_enabled     = true

  force_password_change = true
}

output "created_users" {
  value = { for k, v in azuread_user.users : k => v.user_principal_name }
}
```

> **Note**: Bicep は Azure Resource Manager (ARM) のリソースを管理するためのツールであり、Entra ID ユーザの作成は ARM の管理対象外です。Entra ID のリソース管理には Terraform または Microsoft Graph API を使用してください。

---

## ユーザの一括削除

作成したユーザを一括削除する場合のコマンドも記載します。

### Azure CLI

```bash
# 単一ユーザの削除
az ad user delete --id user001@contoso.onmicrosoft.com

# 一括削除（パターンマッチ）
for i in $(seq -w 1 10); do
  UPN="user${i}@contoso.onmicrosoft.com"
  echo "Deleting ${UPN} ..."
  az ad user delete --id "${UPN}" 2>/dev/null && echo "  ✅ Deleted" || echo "  ⚠️ Not found or failed"
done
```

### PowerShell

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All"

1..10 | ForEach-Object {
    $num = $_.ToString("000")
    $upn = "user${num}@contoso.onmicrosoft.com"

    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '${upn}'" -ErrorAction Stop
        Remove-MgUser -UserId $user.Id -ErrorAction Stop
        Write-Host "✅ $upn deleted" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️ $upn not found or failed" -ForegroundColor Yellow
    }
}

Disconnect-MgGraph
```

---

## 方法の比較

| 方法 | 適したケース | 必要なツール | 並列実行 |
|---|---|---|---|
| Azure CLI | Linux / macOS 環境、少〜中規模 | `az` CLI | `xargs -P` で可能 |
| PowerShell + Graph | Windows 環境、中〜大規模 | `Microsoft.Graph` モジュール | `ForEach-Object -Parallel` で可能 |
| Graph REST API | CI/CD パイプライン、他言語統合 | HTTP クライアント | 非同期リクエストで可能 |
| CSV + スクリプト | ハンズオン一括構築 | `az` CLI または PowerShell | スクリプトに依存 |
| Terraform | IaC で管理したい場合 | `terraform` CLI | `terraform apply` で自動 |

---

## セキュリティに関する注意事項

- **パスワードの管理**: CSV やスクリプトに平文でパスワードを記載する場合は、`.gitignore` に追加して Git にコミットしないでください
- **Azure Key Vault の活用**: パスワードを Key Vault に格納し、スクリプトから参照する方法を推奨します
- **初回パスワード変更の強制**: `forceChangePasswordNextSignIn` を `true` に設定することを強く推奨します
- **最小権限の原則**: ユーザ作成に必要な最小限のロール（ユーザー管理者）を使用してください
- **監査ログの確認**: ユーザ作成後、Entra ID の監査ログで操作が正しく記録されていることを確認してください

---

## 参考リンク

- [az ad user create - Azure CLI リファレンス](https://learn.microsoft.com/ja-jp/cli/azure/ad/user#az-ad-user-create)
- [New-MgUser - Microsoft Graph PowerShell リファレンス](https://learn.microsoft.com/ja-jp/powershell/module/microsoft.graph.users/new-mguser)
- [Microsoft Graph API - ユーザの作成](https://learn.microsoft.com/ja-jp/graph/api/user-post-users)
- [Terraform AzureAD Provider - azuread_user](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/user)
