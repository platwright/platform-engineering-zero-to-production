# Multi-stage, hardened build (the course default from Modules 02.5 / 02.7):
# static binary on a distroless non-root base — small, non-root, no shell.
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
