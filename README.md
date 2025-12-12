# Deploy the users
fly apps create users-api
fly secrets set DATABASE_URL="" -c fly.users.toml
fly deploy -c fly.users.toml

# Deploy postgres
fly apps create barcode-db
fly secrets set POSTGRES_PASSWORD="supersecretpassword" -c fly.db.toml

if the app is already running, fly -a barcode-db secrets set ...

fly volumes create pg_data \
  --size 10 \
  --region iad \
  -a barcode-db

fly deploy -c ./db/fly.db.toml

