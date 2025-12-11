FROM golang:1.22 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG SERVICE_PATH=./services/users-api

RUN echo "Building service at ${SERVICE_PATH}" \
    && CGO_ENABLED=0 GOOS=linux go build -o /app/bin/app ${SERVICE_PATH}

FROM alpine:3.20

WORKDIR /app

RUN adduser -D appuser
USER appuser

COPY --from=builder /app/bin/app /app/app

EXPOSE 8080

CMD ["/app/app"]
