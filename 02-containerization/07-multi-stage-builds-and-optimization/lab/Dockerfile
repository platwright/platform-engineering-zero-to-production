# Multi-stage AND cross-compiled: building for arm64 on an amd64 host (or vice versa)
# is fast because only the Go compiler cross-compiles — no QEMU for the build step.
# Buildx injects BUILDPLATFORM and the TARGET* args automatically.
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags="-s -w" -o /app .

# Minimal, non-root runtime (Module 02.5).
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
USER nonroot
ENTRYPOINT ["/app"]
