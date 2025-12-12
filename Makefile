APP_USERS   := barcode-users-api-1
APP_VENUES  := barcode-venues-api-1
APP_POSTS   := barcode-posts-api-1
APP_AUTH    := barcode-auth-api-1
APP_DB      := barcode-db-1
APP_GATEWAY := barcode-gateway

USERS_TOML   := fly.users.toml
VENUES_TOML  := fly.venues.toml
POSTS_TOML   := fly.posts.toml
AUTH_TOML    := fly.auth.toml
DB_TOML      := ./db/fly.db.toml
GATEWAY_TOML := fly.gateway.toml

# Pass at runtime:
#   make create PASSWORD="db-password" DATABASE_URL="postgres://..." JWT_PRIVATE_KEY="..."
DATABASE_URL ?=
PASSWORD ?=
JWT_PRIVATE_KEY ?=

# JWT Configuration (hardcoded)
JWT_PUBLIC_KEY := rc+dEEEorI6DQ+Wu3PaMz12OFEZT3K/pfdS/v7ZdGXk=
JWT_KEY_ID := barcode-v1
JWT_ISSUER := barcode-auth
JWT_AUDIENCE := barcode-api

.PHONY: create delete status \
        create-users create-venues create-posts create-auth create-db create-gateway \
        delete-users delete-venues delete-posts delete-auth delete-db delete-gateway \
        set-users-secrets set-venues-secrets set-posts-secrets set-auth-secrets set-db-secrets set-all-secrets

create: create-db create-users create-venues create-posts create-auth create-gateway

# ----------------------
# USERS API
# ----------------------
create-users:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Creating users API app (if not exists)"
	@fly apps list | grep -q $(APP_USERS) || fly apps create $(APP_USERS)
	@echo "==> Setting users API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(USERS_TOML)
	@echo "==> Deploying users API"
	@fly deploy -c $(USERS_TOML) -a $(APP_USERS)

delete-users:
	@echo "==> Destroying users API app"
	@fly apps destroy $(APP_USERS) --yes || true

set-users-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Setting users API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(USERS_TOML)

# ----------------------
# VENUES API
# ----------------------
create-venues:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Creating venues API app (if not exists)"
	@fly apps list | grep -q $(APP_VENUES) || fly apps create $(APP_VENUES)
	@echo "==> Setting venues API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(VENUES_TOML)
	@echo "==> Deploying venues API"
	@fly deploy -c $(VENUES_TOML) -a $(APP_VENUES)

delete-venues:
	@echo "==> Destroying venues API app"
	@fly apps destroy $(APP_VENUES) --yes || true

set-venues-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Setting venues API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(VENUES_TOML)

# ----------------------
# POSTS API
# ----------------------
create-posts:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Creating posts API app (if not exists)"
	@fly apps list | grep -q $(APP_POSTS) || fly apps create $(APP_POSTS)
	@echo "==> Setting posts API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(POSTS_TOML)
	@echo "==> Deploying posts API"
	@fly deploy -c $(POSTS_TOML) -a $(APP_POSTS)

delete-posts:
	@echo "==> Destroying posts API app"
	@fly apps destroy $(APP_POSTS) --yes || true

set-posts-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Setting posts API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(POSTS_TOML)

# ----------------------
# AUTH API
# ----------------------
create-auth:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@test -n "$(JWT_PRIVATE_KEY)" || (echo "ERROR: JWT_PRIVATE_KEY is required"; exit 1)
	@echo "==> Creating auth API app (if not exists)"
	@fly apps list | grep -q $(APP_AUTH) || fly apps create $(APP_AUTH)
	@echo "==> Setting auth API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_PRIVATE_KEY="$(JWT_PRIVATE_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(AUTH_TOML)
	@echo "==> Deploying auth API"
	@fly deploy -c $(AUTH_TOML) -a $(APP_AUTH)

delete-auth:
	@echo "==> Destroying auth API app"
	@fly apps destroy $(APP_AUTH) --yes || true

set-auth-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@test -n "$(JWT_PRIVATE_KEY)" || (echo "ERROR: JWT_PRIVATE_KEY is required"; exit 1)
	@echo "==> Setting auth API secrets"
	@fly secrets set \
		DATABASE_URL="$(DATABASE_URL)" \
		JWT_PUBLIC_KEY="$(JWT_PUBLIC_KEY)" \
		JWT_PRIVATE_KEY="$(JWT_PRIVATE_KEY)" \
		JWT_KEY_ID="$(JWT_KEY_ID)" \
		JWT_ISSUER="$(JWT_ISSUER)" \
		JWT_AUDIENCE="$(JWT_AUDIENCE)" \
		-c $(AUTH_TOML)

# ----------------------
# POSTGRES
# ----------------------
create-db:
	@test -n "$(PASSWORD)" || (echo "ERROR: PASSWORD is required"; exit 1)
	@echo "==> Creating DB app (if not exists)"
	@fly apps list | grep -q $(APP_DB) || fly apps create $(APP_DB)
	@echo "==> Setting DB secrets"
	@fly secrets set POSTGRES_PASSWORD="$(PASSWORD)" -c $(DB_TOML)
	@echo "==> Deploying Postgres (volume must already exist)"
	@fly deploy -c $(DB_TOML) -a $(APP_DB)

delete-db:
	@echo "==> Destroying DB app (volume preserved)"
	@fly apps destroy $(APP_DB) --yes || true

set-db-secrets:
	@test -n "$(PASSWORD)" || (echo "ERROR: PASSWORD is required"; exit 1)
	@echo "==> Setting DB secrets"
	@fly secrets set POSTGRES_PASSWORD="$(PASSWORD)" -c $(DB_TOML)

# ----------------------
# GATEWAY
# ----------------------
create-gateway:
	@echo "==> Creating gateway app (if not exists)"
	@fly apps list | grep -q $(APP_GATEWAY) || fly apps create $(APP_GATEWAY)
	@echo "==> Deploying gateway"
	@fly deploy -c $(GATEWAY_TOML) -a $(APP_GATEWAY)

delete-gateway:
	@echo "==> Destroying gateway app"
	@fly apps destroy $(APP_GATEWAY) --yes || true

# ----------------------
# SECRETS (ALL APIs)
# ----------------------
set-all-secrets: set-users-secrets set-venues-secrets set-posts-secrets set-auth-secrets

# ----------------------
# DELETE ALL
# ----------------------
delete: delete-users delete-venues delete-posts delete-auth delete-db delete-gateway

# ----------------------
# STATUS
# ----------------------
status:
	@fly status -a $(APP_USERS)   || true
	@fly status -a $(APP_VENUES)  || true
	@fly status -a $(APP_POSTS)   || true
	@fly status -a $(APP_AUTH)    || true
	@fly status -a $(APP_DB)      || true
	@fly status -a $(APP_GATEWAY) || true

