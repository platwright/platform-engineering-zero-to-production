# syntax=docker/dockerfile:1

# ---- build stage ----
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
# Static, stripped binary for a minimal runtime image.
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/app .

# ---- runtime stage ----
# Distroless nonroot: no shell, runs as an unprivileged user by default.
FROM ${{ values.baseImage }}
WORKDIR /
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
