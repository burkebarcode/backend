module github.com/burkebarcode/backend/shared/recommendations

go 1.25.3

require (
	github.com/burkebarcode/backend/shared/db v0.0.0-00010101000000-000000000000
	github.com/jackc/pgx/v5 v5.7.6
)

replace github.com/burkebarcode/backend/shared/db => ../db
