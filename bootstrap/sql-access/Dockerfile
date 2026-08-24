FROM golang:1.25-alpine AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/sql-access-bootstrap .

FROM alpine:3.22

RUN apk add --no-cache ca-certificates \
    && addgroup -g 65532 -S bootstrap \
    && adduser -u 65532 -S -G bootstrap bootstrap

COPY --from=build /out/sql-access-bootstrap /sql-access-bootstrap
USER 65532:65532
ENTRYPOINT ["/sql-access-bootstrap"]
