# Build a tiny, static, NON-ROOT image: small attack surface, fast to scan,
# and nothing to promote but the exact bytes you built (Module 02.5 + 06.5).

FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
