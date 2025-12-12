# Deploy postgres
fly apps create barcode-db-1
fly secrets set POSTGRES_PASSWORD="supersecretpassword" -c fly.db.toml

if the app is already running, fly -a barcode-db secrets set ...

fly volumes create pg_data \
  --size 10 \
  --region iad \
  -a barcode-db

fly deploy -c ./db/fly.db.toml

# USAGE

make create DATABASE_URL="" PASSWORD=""
