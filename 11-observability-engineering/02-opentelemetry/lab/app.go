// app.go -- a SKETCH of an OpenTelemetry-instrumented Go service.
//
// This is reference material, not part of the runnable lab (the lab uses
// telemetrygen so you need no Go toolchain). It shows the two kinds of
// instrumentation working together:
//
//   - AUTO: otelhttp wraps the HTTP handler, emitting a span + RED metrics for
//     every request with no per-handler code.
//   - MANUAL: you open a span around a business operation ("charge-card") and
//     attach domain attributes the auto layer cannot know.
//
// It exports OTLP to the Collector agent at $OTEL_EXPORTER_OTLP_ENDPOINT
// (e.g. otel-agent:4317), so routing to a backend is the Collector's job.
//
// Dependencies (for reference):
//   go.opentelemetry.io/otel
//   go.opentelemetry.io/otel/sdk/trace
//   go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
//   go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp

package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// initTracer wires an OTLP exporter into a TracerProvider. The endpoint and
// headers come from standard OTEL_* env vars, so the same binary points at any
// Collector without a code change.
func initTracer(ctx context.Context) (func(context.Context) error, error) {
	exporter, err := otlptracegrpc.New(ctx) // reads OTEL_EXPORTER_OTLP_ENDPOINT
	if err != nil {
		return nil, err
	}

	// service.name is a semantic convention -- it must be set, consistently.
	res, err := resource.New(ctx,
		resource.WithAttributes(semconv.ServiceName("checkout")),
	)
	if err != nil {
		return nil, err
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter), // batch spans, like the Collector's batch processor
		sdktrace.WithResource(res),
		// Head sampling at the edge; tail sampling happens later in the gateway.
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(0.1))),
	)
	otel.SetTracerProvider(tp)
	return tp.Shutdown, nil
}

var tracer = otel.Tracer("checkout")

// chargeCard is a MANUAL span around a business operation the auto layer cannot
// see. Domain attributes (tenant, amount) make the trace queryable by meaning.
func chargeCard(ctx context.Context, tenantID string, amountCents int64) error {
	ctx, span := tracer.Start(ctx, "charge-card")
	defer span.End()
	span.SetAttributes(
		attribute.String("tenant.id", tenantID),
		attribute.Int64("order.amount_cents", amountCents),
	)

	// ... call the payments service (its client would propagate trace context) ...
	time.Sleep(20 * time.Millisecond)
	return nil
}

func checkoutHandler(w http.ResponseWriter, r *http.Request) {
	if err := chargeCard(r.Context(), r.Header.Get("X-Tenant"), 4200); err != nil {
		http.Error(w, "payment failed", http.StatusBadGateway)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func main() {
	ctx := context.Background()
	shutdown, err := initTracer(ctx)
	if err != nil {
		log.Fatalf("init tracer: %v", err)
	}
	defer func() { _ = shutdown(ctx) }()

	// otelhttp = AUTO instrumentation: one span + metrics per request, for free.
	handler := otelhttp.NewHandler(http.HandlerFunc(checkoutHandler), "POST /checkout")
	http.Handle("/checkout", handler)

	log.Println("checkout listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
