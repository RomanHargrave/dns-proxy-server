# Build web interface
FROM node:12-alpine AS web_assets

COPY app /app

WORKDIR /app

ENV PUBLIC_URL=/static

RUN npm install \
	&& npm run build \
	&& find ./build -name '*.map' -delete

# Build service
FROM golang:1.12.9 AS service

LABEL dps.container=true

COPY . /app

WORKDIR /app

ENV GOPATH=/app \
	MG_WORK_DIR=/app/src/github.com/mageddo/dns-proxy-server \
	GOOS=linux \
	GOARCH=amd64 \
	GO111MODULE=on

ARG RUN_TESTS=1
ARG	APP_VERSION=latest

RUN bash -c 'if [ ${RUN_TESTS} = 1 ]; then \
	go test -p 1 -cover -ldflags "-X github.com/mageddo/dns-proxy-server/flags.version=test" ./.../ \
	&& rm -rf build/ \
	&& mkdir -p build \
	&& rm go.mod; \
	fi;'

RUN go build -o build/dns-proxy-server -ldflags "-X github.com/mageddo/dns-proxy-server/flags.version=${APP_VERSION}"

FROM debian:10-slim

WORKDIR /app

COPY --from=web_assets /app/build /app/static
COPY --from=service /app/build/dns-proxy-server /app/dns-proxy-server

LABEL dps.container=true

VOLUME ["/var/run/docker.sock", "/var/run/docker.sock"]
VOLUME ["/app/conf"]

CMD ["bash", "-c", "/app/dns-proxy-server"]
