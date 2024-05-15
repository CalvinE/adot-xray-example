package main

import (
	"context"
	"fmt"
	"net/http"
	"strconv"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/contrib/propagators/aws/xray"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/trace"
	apptrace "go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
)

var tracer apptrace.Tracer

func initTracing(ctx context.Context) error {
	// Create and start new OTLP trace exporter
	traceExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithEndpoint("0.0.0.0:4317"),
		otlptracegrpc.WithDialOption(grpc.WithBlock()),
	)
	if err != nil {
		return fmt.Errorf("failed to create new OTLP trace exporter: %v", err)
	}
	idg := xray.NewIDGenerator()

	tp := trace.NewTracerProvider(
		trace.WithSampler(trace.AlwaysSample()),
		trace.WithBatcher(traceExporter),
		trace.WithIDGenerator(idg),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(xray.Propagator{})

	tracer = tp.Tracer("adot-demo/mathservice")

	return nil
}

func setSpanError(span apptrace.Span, description string, err error, attributes ...attribute.KeyValue) {
	span.SetStatus(codes.Error, description)
	span.SetAttributes(attribute.String("description", description))
	if err != nil {
		span.RecordError(err)
		span.SetAttributes(attribute.String("err", err.Error()))
	}
	if len(attributes) > 0 {
		span.SetAttributes(attributes...)
	}
	// events are ignored by x-ray...
	span.AddEvent(description, apptrace.WithAttributes(attributes...))
}

func initMetrics(ctx context.Context) error {
	// Create and start new OTLP metric exporter
	metricExporter, err := otlpmetricgrpc.New(ctx,
		otlpmetricgrpc.WithInsecure(),
		otlpmetricgrpc.WithEndpoint("0.0.0.0:4317"),
		otlpmetricgrpc.WithDialOption(grpc.WithBlock()),
	)
	if err != nil {
		return fmt.Errorf("failed to create new OTLP metric exporter: %v", err)
	}

	mp := metric.NewMeterProvider(metric.WithReader(metric.NewPeriodicReader(metricExporter)))

	otel.SetMeterProvider(mp)

	return nil
}

func validateOp(ctx context.Context, op string) (int, error) {
	_, span := tracer.Start(ctx, "validateOp")
	defer span.End()
	val, err := strconv.Atoi(op)
	if err != nil {
		setSpanError(span, "failed to validate operand", err, attribute.String("operand", op), attribute.String("err", err.Error()))
		return 0, err
	}
	return val, nil
}

func addHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "addHandler")
	defer span.End()
	query := r.URL.Query()
	op1String := query.Get("op1")
	op1, err := validateOp(ctx, op1String)
	if err != nil {
		setSpanError(span, "op1 validation failed", err, attribute.String("op1", op1String))
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}
	if op1 < 0 {
		// Throw error on negative op1
	}
	op2String := query.Get("op2")
	op2, err := validateOp(ctx, op2String)
	if err != nil {
		setSpanError(span, "op2 validation failed", err, attribute.String("op2", op2String))
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}

	result := op1 + op2

	w.Write([]byte(strconv.Itoa(result)))
}

// A simple health check handler
func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Println("healthcheck hit")
	w.WriteHeader(http.StatusOK)
}

func main() {
	ctx := context.Background()
	if err := initTracing(ctx); err != nil {
		fmt.Printf("init traces errored: %v", err)
		return
	}
	if err := initMetrics(ctx); err != nil {
		fmt.Printf("init metrics errored: %v", err)
		return
	}
	fmt.Println("starting up mathservice")
	mux := http.NewServeMux()
	mux.Handle("GET /add", otelhttp.NewHandler(http.HandlerFunc(addHandler), "add"))
	mux.HandleFunc("GET /health", healthCheckHandler)
	if err := http.ListenAndServe(":8080", mux); err != nil {
		fmt.Printf("HTTP server errored... %v", err)
	}
}
