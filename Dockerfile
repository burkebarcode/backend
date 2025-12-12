FROM golang:1.25 AS builder

WORKDIR /app

# Copy workspace files first so Go knows about all modules
COPY go.work go.work.sum ./

# Copy all modules (services + shared) into the workspace
COPY services ./services
COPY shared ./shared

ARG SERVICE_PATH=services/api-users

# Move into the service's module directory
WORKDIR /app/${SERVICE_PATH}

# Download dependencies for this service module
RUN go mod download

# Build the service binary
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/bin/app .

# ---------- Stage 2: Minimal runtime ----------
FROM alpine:3.20

WORKDIR /app

RUN adduser -D appuser
USER appuser

COPY --from=builder /app/bin/app /app/app

EXPOSE 8080

CMD ["/app/app"]

