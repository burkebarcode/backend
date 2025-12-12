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

DATABASE_URL ?=

.PHONY: create delete status \
        create-users create-venues create-posts create-auth create-db create-gateway \
        delete-users delete-venues delete-posts delete-auth delete-db delete-gateway \
        set-users-secrets set-venues-secrets set-posts-secrets set-auth-secrets set-all-secrets

create: create-db create-users create-venues create-posts create-auth create-gateway

# USERS API
create-users:
	@echo "==> Creating users API app (if not exists)"
	@fly apps list | grep -q $(APP_USERS) || fly apps create $(APP_USERS)
	@echo "==> Setting users API secrets (optional: run make set-users-secrets)"
	@echo "==> Deploying users API"
	@fly deploy -c $(USERS_TOML) -a $(APP_USERS)

delete-users:
	@echo "==> Destroying users API app"
	@fly apps destroy $(APP_USERS) --yes || true

set-users-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Setting users API secrets"
	@fly secrets set DATABASE_URL="$(DATABASE_URL)" -c $(USERS_TOML)

# VENUES API
create-venues:
	@echo "==> Creating venues API app (if not exists)"
	@fly apps list | grep -q $(APP_VENUES) || fly apps create $(APP_VENUES)
	@echo "==> Setting venues API secrets (optional: run make set-venues-secrets)"
	@echo "==> Deploying venues API"
	@fly deploy -c $(VENUES_TOML) -a $(APP_VENUES)

delete-venues:
	@echo "==> Destroying venues API app"
	@fly apps destroy $(APP_VENUES) --yes || true

set-venues-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Setting venues API secrets"
	@fly secrets set DATABASE_URL="$(DATABASE_URL)" -c $(VENUES_TOML)

# POSTS API
create-posts:
	@echo "==> Creating posts API app (if not exists)"
	@fly apps list | grep -q $(APP_POSTS) || fly apps create $(APP_POSTS)
	@echo "==> Setting posts API secrets (optional: run make set-posts-secrets)"
	@echo "==> Deploying posts API"
	@fly deploy -c $(POSTS_TOML) -a $(APP_POSTS)

delete-posts:
	@echo "==> Destroying posts API app"
	@fly apps destroy $(APP_POSTS) --yes || true

set-posts-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Setting posts API secrets"
	@fly secrets set DATABASE_URL="$(DATABASE_URL)" -c $(POSTS_TOML)

# AUTH API
create-auth:
	@echo "==> Creating auth API app (if not exists)"
	@fly apps list | grep -q $(APP_AUTH) || fly apps create $(APP_AUTH)
	@echo "==> Setting auth API secrets (optional: run make set-auth-secrets)"
	@echo "==> Deploying auth API"
	@fly deploy -c $(AUTH_TOML) -a $(APP_AUTH)

delete-auth:
	@echo "==> Destroying auth API app"
	@fly apps destroy $(APP_AUTH) --yes || true

set-auth-secrets:
	@test -n "$(DATABASE_URL)" || (echo "ERROR: DATABASE_URL is required"; exit 1)
	@echo "==> Setting auth API secrets"
	@fly secrets set DATABASE_URL="$(DATABASE_URL)" -c $(AUTH_TOML)

# POSTGRES
create-db:
	@echo "==> Creating DB app (if not exists)"
	@fly apps list | grep -q $(APP_DB) || fly apps create $(APP_DB)
	@echo "==> Setting DB secrets"
	@fly secrets set POSTGRES_PASSWORD="supersecretpassword" -a $(APP_DB)
	@echo "==> Deploying Postgres (volume must already exist)"
	@fly deploy -c $(DB_TOML) -a $(APP_DB)

delete-db:
	@echo "==> Destroying DB app (volume preserved)"
	@fly apps destroy $(APP_DB) --yes || true

# GATEWAY
create-gateway:
	@echo "==> Creating gateway app (if not exists)"
	@fly apps list | grep -q $(APP_GATEWAY) || fly apps create $(APP_GATEWAY)
	@echo "==> Deploying gateway"
	@fly deploy -c $(GATEWAY_TOML) -a $(APP_GATEWAY)

delete-gateway:
	@echo "==> Destroying gateway app"
	@fly apps destroy $(APP_GATEWAY) --yes || true

# SECRETS (ALL APIs)
# make set-all-secrets   DATABASE_URL="postgres://..."
set-all-secrets: set-users-secrets set-venues-secrets set-posts-secrets set-auth-secrets

# DELETE ALL
delete: delete-users delete-venues delete-posts delete-auth delete-db delete-gateway

# STATUS
status:
	@fly status -a $(APP_USERS)   || true
	@fly status -a $(APP_VENUES)  || true
	@fly status -a $(APP_POSTS)   || true
	@fly status -a $(APP_AUTH)    || true
	@fly status -a $(APP_DB)      || true
	@fly status -a $(APP_GATEWAY) || true

