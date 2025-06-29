# Auth0 + Rails デモアプリケーション

Auth0でOpenID Connect (OIDC)のデモを行うRailsアプリケーションです。スコープベースの権限管理とRBACを実装しています。

## システム構成

### C4図: システム全体構成

```mermaid
C4Context
    title Auth0 + Rails OIDCデモアプリケーション システム構成

    Person(user, "ユーザー", "Webアプリケーションを利用するエンドユーザー")
    
    System_Boundary(webapp, "Rails Auth0デモアプリ") {
        Container(browser, "Webブラウザ", "HTML/CSS/JavaScript", "ユーザーインターフェース<br/>・ホームページ(/)<br/>・ダッシュボード(/dashboard)")
        Container(rails, "Rails アプリケーション", "Ruby on Rails 7", "Auth0コントローラー<br/>・認証処理<br/>・JWT検証<br/>・セッション管理")
        ContainerDb(database, "データベース", "SQLite/PostgreSQL", "セッションストア")
    }
    
    System_Ext(auth0, "Auth0", "認証・認可プラットフォーム", "・ユーザー認証<br/>・JWT発行<br/>・スコープ管理<br/>・APIアクセス制御")
    
    Rel(user, browser, "アクセス", "HTTPS")
    Rel(browser, rails, "HTTP リクエスト", "/auth/auth0, /dashboard")
    Rel(rails, database, "セッション管理", "Rails Session Store")
    Rel(browser, auth0, "認証フロー", "OpenID Connect<br/>Authorization Code Flow")
    Rel(rails, auth0, "トークン交換・検証", "/oauth/token<br/>/userinfo<br/>JWT検証")
    
    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

### Rails内部構成

```mermaid
C4Container
    title Rails Auth0デモアプリ 内部構成とルーティング

    Person(user, "ユーザー")
    System_Ext(auth0, "Auth0", "認証プラットフォーム")
    
    Container_Boundary(rails_app, "Rails アプリケーション") {
        Container(routes, "ルーティング", "routes.rb", "・/ → home#index<br/>・/auth/auth0 → auth0#login<br/>・/auth/auth0/callback → auth0#callback<br/>・/logout → auth0#logout<br/>・/dashboard → dashboard#index")
        Container(auth0_ctrl, "Auth0Controller", "Ruby Class", "・login() - 認証URL構築<br/>・callback() - トークン交換<br/>・logout() - Auth0ログアウト<br/>・JWT検証・セッション管理")
        Container(dashboard_ctrl, "DashboardController", "Ruby Class", "認証済みユーザー向け<br/>・スコープ検証<br/>・ユーザー情報表示")
        Container(application_ctrl, "ApplicationController", "Ruby Class", "共通処理<br/>・logged_in_using_omniauth?<br/>・認証チェック")
        Container(session_store, "セッションストア", "Rails Session", "・user_id, email, name<br/>・access_token, scopes<br/>・token_expires_at<br/>・provider: 'auth0'")
    }
    
    ContainerDb(db, "データベース", "SQLite", "セッションデータ")
    Container(views, "ビューテンプレート", "ERB", "・home/index.html.erb<br/>・dashboard/index.html.erb<br/>・layouts/application.html.erb")

    Rel(user, routes, "HTTP リクエスト", "GET /auth/auth0")
    Rel(routes, auth0_ctrl, "ルーティング", "auth0#login")
    Rel(auth0_ctrl, auth0, "認証・トークン取得", "OAuth 2.0 / OIDC")
    Rel(auth0_ctrl, session_store, "セッション管理", "user情報・トークン保存")
    Rel(dashboard_ctrl, session_store, "認証状態確認", "スコープ・権限チェック")
    Rel(application_ctrl, session_store, "認証チェック", "logged_in_using_omniauth?")
    Rel(session_store, db, "永続化", "セッションデータ")
    Rel(dashboard_ctrl, views, "レンダリング", "ユーザー情報表示")
    
    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## 認証フロー

### 5つのユースケースシナリオ

```mermaid
sequenceDiagram
    participant U as ユーザー
    participant B as ブラウザ
    participant R as Rails App<br/>(Auth0Controller)
    participant A as Auth0
    participant DB as データベース

    Note over U,DB: ユースケース1: 初回ログイン
    U->>B: ホームページ(/)にアクセス
    B->>R: GET /
    R->>R: logged_in_using_omniauth?<br/>(false)
    R->>B: ホームページ表示（ログインボタン）
    U->>B: ログインボタンクリック
    B->>R: GET /auth/auth0
    
    Note over R: build_auth_url()
    Note over R: スコープ設定：<br/>openid profile email<br/>read:profile read:dashboard<br/>read:user write:user
    
    R->>R: セッションクリア<br/>state生成・保存
    R->>B: Auth0認証URL<br/>にリダイレクト
    B->>A: 認証ページ表示
    U->>A: ログイン情報入力
    A->>A: ユーザー認証
    A->>B: 認証コード + state<br/>で /auth/auth0/callback にリダイレクト

    B->>R: GET /auth/auth0/callback<br/>(code, state)
    R->>R: state検証
    R->>A: POST /oauth/token<br/>(認証コード交換)
    A->>R: アクセストークン<br/>IDトークン返却
    
    Note over R: verify_jwt_token()
    R->>R: JWT検証・デコード
    R->>A: GET /userinfo<br/>(Bearer Token)
    A->>R: ユーザー情報<br/>(sub, email, name, picture)
    
    Note over R: セッション設定
    R->>DB: セッション保存<br/>・user_id, email, name<br/>・access_token, scopes<br/>・token_expires_at
    R->>B: /dashboard にリダイレクト
    B->>U: ダッシュボード表示

    Note over U,DB: ユースケース2: ログイン済みユーザーのアクセス
    U->>B: 新しいタブで/(ホーム)にアクセス
    B->>R: GET /
    R->>R: logged_in_using_omniauth?
    R->>DB: セッション情報取得
    R->>R: セッション有効確認<br/>token_expires_at > 現在時刻
    R->>B: ログイン済み状態のホームページ<br/>（ユーザー名・ログアウトボタン表示）
    
    U->>B: ダッシュボードリンククリック
    B->>R: GET /dashboard
    R->>R: logged_in_using_omniauth?<br/>(true)
    R->>DB: セッション情報取得
    R->>R: スコープ確認<br/>(read:dashboard)
    R->>B: ダッシュボード表示<br/>（キャッシュされたユーザー情報）
    B->>U: 即座にダッシュボード表示

    Note over U,DB: ユースケース3: トークン期限切れの場合
    U->>B: しばらく後にダッシュボードアクセス
    B->>R: GET /dashboard
    R->>R: logged_in_using_omniauth?
    R->>DB: セッション情報取得
    R->>R: token_expires_at < 現在時刻<br/>（期限切れ検出）
    R->>DB: セッション削除
    R->>B: ホームページにリダイレクト<br/>alert: "セッションが期限切れです"
    
    U->>B: 再度ログインボタンクリック
    B->>R: GET /auth/auth0
    Note over A: Auth0セッション有効の場合
    B->>A: 認証ページ（既にログイン済み）
    A->>B: 自動的に認証コード発行<br/>（ユーザー入力不要）
    B->>R: GET /auth/auth0/callback<br/>(code, state)
    Note over R: トークン交換・セッション再作成
    R->>B: /dashboard にリダイレクト

    Note over U,DB: ユースケース4: Auth0セッション期限切れ
    U->>B: 長時間後にログイン試行
    B->>R: GET /auth/auth0
    B->>A: 認証ページアクセス
    Note over A: Auth0セッションも期限切れ
    A->>B: ログインフォーム表示
    U->>A: 再度ログイン情報入力
    A->>B: 認証コード発行
    Note over R: 通常の認証フロー
    
    Note over U,DB: ユースケース5: 明示的ログアウト
    U->>B: ログアウトボタンクリック
    B->>R: GET /logout
    R->>DB: セッション完全削除<br/>reset_session
    R->>B: Auth0ログアウトURL<br/>(/v2/logout)にリダイレクト
    B->>A: Auth0セッション削除
    A->>B: アプリケーション<br/>ルートページにリダイレクト
    B->>U: 未ログイン状態のホームページ
```

### スコープと権限管理

```mermaid
flowchart TD
    A[ユーザーログイン開始] --> B[Auth0認証URL構築]
    B --> C{スコープ設定}
    
    C --> C1["openid<br/>(必須: OIDC)"]
    C --> C2["profile<br/>(プロフィール情報)"]
    C --> C3["email<br/>(メールアドレス)"]
    C --> C4["read:profile<br/>(プロフィール読み取り)"]
    C --> C5["read:dashboard<br/>(ダッシュボード読み取り)"]
    C --> C6["read:user<br/>(ユーザー情報読み取り)"]
    C --> C7["write:user<br/>(ユーザー情報更新)"]
    
    C1 --> D[Auth0認証ページ]
    C2 --> D
    C3 --> D
    C4 --> D
    C5 --> D
    C6 --> D
    C7 --> D
    
    D --> E[ユーザー認証成功]
    E --> F[認証コード発行]
    F --> G[Rails: コード→トークン交換]
    G --> H[アクセストークン取得]
    H --> I[JWT検証・デコード]
    
    I --> J{取得したスコープ}
    J --> J1["openid profile email"]
    J --> J2["read:profile read:dashboard"]
    J --> J3["read:user write:user"]
    
    J1 --> K[基本ユーザー情報取得]
    J2 --> L[ダッシュボードアクセス権限]
    J3 --> M[ユーザー管理権限]
    
    K --> N[セッション保存]
    L --> N
    M --> N
    
    N --> O[Rails Controller]
    O --> P{権限チェック}
    
    P -->|read:dashboard| Q[ダッシュボード表示]
    P -->|read:profile| R[プロフィール表示]
    P -->|write:user| S[ユーザー情報更新機能]
    P -->|権限なし| T[アクセス拒否]
    
    style C1 fill:#e1f5fe
    style C2 fill:#e8f5e8
    style C3 fill:#fff3e0
    style C4 fill:#f3e5f5
    style C5 fill:#e0f2f1
    style C6 fill:#fff8e1
    style C7 fill:#fce4ec
```

## 技術仕様

### バージョン情報
- **Ruby**: 3.4.1
- **Rails**: 8.0.2
- **認証プロトコル**: OpenID Connect (OIDC) + OAuth 2.0
- **認証フロー**: Authorization Code Flow
- **トークン形式**: JWT (JSON Web Token)

### 主要機能
- Auth0を使用したOIDC認証
- スコープベースの権限管理
- セッション管理とトークン期限管理
- RBAC (Role-Based Access Control) 対応
- 自動ログアウト・再認証機能

## Auth0設定

### 1. Application設定

1. **Auth0ダッシュボード**にログイン
2. **Applications** → **Create Application**をクリック
3. 以下を設定：
   - **Name**: `Rails Auth0 Demo`
   - **Application Type**: `Regular Web Application`
   - **Technology**: `Ruby on Rails`

4. **Settings**タブで以下を設定：
   ```
   Allowed Callback URLs:
   http://localhost:3000/auth/auth0/callback

   Allowed Logout URLs:
   http://localhost:3000

   Allowed Web Origins:
   http://localhost:3000
   ```

5. **Client ID**, **Client Secret**, **Domain**をメモ

### 2. API設定（RBAC用）

1. **APIs** → **Create API**をクリック
2. 以下を設定：
   ```
   Name: Rails Auth0 Demo API
   Identifier: https://rails-auth0-demo.example.com
   Signing Algorithm: RS256
   ```

3. **Settings**で以下を有効化：
   ```
   ✅ Enable RBAC
   ✅ Add Permissions in the Access Token
   ```

4. **Permissions**タブで権限を追加：
   ```
   read:profile - プロフィール読み取り権限
   read:dashboard - ダッシュボード読み取り権限
   read:user - ユーザー情報読み取り権限
   write:user - ユーザー情報更新権限
   ```

### 3. Application にAPIを関連付け

1. **Applications** → 作成したApplication → **APIs**タブ
2. **Authorize** → 作成したAPIを選択
3. **Scopes** で必要な権限を選択

### 4. Role設定（RBAC）

1. **User Management** → **Roles** → **Create Role**
2. ロールを作成：
   ```
   Name: Dashboard User
   Description: ダッシュボードアクセス権限を持つユーザー
   ```

3. **Permissions**タブで権限を追加：
   - `read:profile`
   - `read:dashboard`
   - `read:user`

4. **Users**タブでユーザーにロールを割り当て

### 5. Test User作成

1. **User Management** → **Users** → **Create User**
2. テストユーザーを作成し、上記ロールを割り当て

## 環境構築

### 前提条件
- Ruby 3.4.1+
- Rails 8.0.2+
- Git

### セットアップ手順

1. **リポジトリクローン**
   ```bash
   git clone https://github.com/kyoneken/auth0_sample.git
   cd auth0_sample
   ```

2. **依存関係インストール**
   ```bash
   bundle install
   ```

3. **環境変数設定**
   
   `.env`ファイルを作成：
   ```bash
   touch .env
   ```
   
   以下の内容を追加：
   ```env
   AUTH0_DOMAIN=your-tenant.auth0.com
   AUTH0_CLIENT_ID=your_client_id
   AUTH0_CLIENT_SECRET=your_client_secret
   AUTH0_AUDIENCE=https://rails-auth0-demo.example.com
   ```

4. **データベース設定**
   ```bash
   rails db:create
   rails db:migrate
   ```

5. **サーバー起動**
   ```bash
   rails server
   ```

6. **アプリケーションアクセス**
   
   ブラウザで `http://localhost:3000` を開く

## 実行方法

### 基本的な使用フロー

1. **ホームページアクセス**
   - `http://localhost:3000` にアクセス
   - 未ログイン状態のページが表示

2. **ログイン**
   - 「Login with Auth0」ボタンをクリック
   - Auth0認証ページにリダイレクト
   - テストユーザーでログイン

3. **ダッシュボードアクセス**
   - ログイン成功後、自動的にダッシュボードへ
   - ユーザー情報とスコープ情報を確認

4. **ログアウト**
   - 「Logout」ボタンでログアウト
   - Auth0セッションも削除

### URL構成

| パス | 機能 | 認証要否 |
|------|------|----------|
| `/` | ホームページ | 不要 |
| `/auth/auth0` | Auth0ログイン開始 | 不要 |
| `/auth/auth0/callback` | Auth0コールバック | 自動 |
| `/dashboard` | ダッシュボード | 必要 |
| `/logout` | ログアウト | 必要 |

## トラブルシューティング

### よくある問題と解決方法

#### 1. 認証エラー

**症状**: `Invalid state parameter` エラー
```
解決方法:
1. ブラウザのキャッシュとCookieをクリア
2. Railsサーバーを再起動
3. セッションストアをクリア
```

**症状**: `No authorization code received` エラー
```
解決方法:
1. Auth0のCallback URLが正しく設定されているか確認
2. 環境変数が正しく設定されているか確認
```

#### 2. セッション関連の問題

**症状**: ログインしても認証状態が保持されない
```
解決方法:
1. セッションストアのクリア
2. ブラウザの再起動
3. Cookieの有効性確認
```

#### 3. スコープ・権限エラー

**症状**: `Access denied` エラー
```
解決方法:
1. Auth0でユーザーに適切なロールが割り当てられているか確認
2. APIのPermissions設定を確認
3. Applicationの認可設定を確認
```

### キャッシュ削除方法

#### Railsアプリケーション側
```bash
# セッションストアクリア
rails runner "Rails.cache.clear"

# 開発環境の一時ファイル削除
rails tmp:clear

# サーバー再起動
rails server
```

#### ブラウザ側
```
Chrome/Firefox:
1. 開発者ツール (F12) を開く
2. Application/Storage タブを選択
3. Cookies と Local Storage をクリア
4. または設定から「閲覧データを削除」

Safari:
1. 開発メニュー → 「キャッシュを空にする」
2. または環境設定 → プライバシー → 「Webサイトデータを管理」
```

#### Auth0セッション削除
```
1. Auth0ログアウトURLに直接アクセス：
   https://your-tenant.auth0.com/v2/logout

2. または /logout エンドポイントを使用
   http://localhost:3000/logout
```

### ログ確認方法

#### Rails開発ログ
```bash
# ログをリアルタイム監視
tail -f log/development.log

# Auth0関連のログのみ抽出
grep "Auth0" log/development.log
```

#### Auth0ダッシュボード
```
1. Auth0ダッシュボード → Monitoring → Logs
2. 直近の認証試行とエラーを確認
3. エラーの詳細情報を確認
```

### 環境変数チェック

```bash
# 環境変数が正しく読み込まれているか確認
rails console

# コンソール内で確認
ENV['AUTH0_DOMAIN']
ENV['AUTH0_CLIENT_ID']
ENV['AUTH0_CLIENT_SECRET']
ENV['AUTH0_AUDIENCE']
```

## コントリビューション

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチをプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は `LICENSE` ファイルを参照してください。

## 参考資料

- [Auth0 Documentation](https://auth0.com/docs)
- [Rails Guides](https://guides.rubyonrails.org/)
- [OpenID Connect Specification](https://openid.net/connect/)
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)