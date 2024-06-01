package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strconv"

	"go.opentelemetry.io/contrib/detectors/aws/ecs"
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

const loggerKey = "loggerKey"

var tracer apptrace.Tracer

func envOrDefault(name string, defaultValue string) string {
	if val, exists := os.LookupEnv(name); exists {
		return val
	}
	return defaultValue
}

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

	ecsResourceDetector := ecs.NewResourceDetector()
	resource, err := ecsResourceDetector.Detect(ctx)
	if err != nil {
		return fmt.Errorf("failed to build the ecs resource detector: %v", err)
	}

	tp := trace.NewTracerProvider(
		trace.WithSampler(trace.AlwaysSample()),
		trace.WithBatcher(traceExporter),
		trace.WithIDGenerator(idg),
		trace.WithResource(resource),
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
	logger, err := getTraceAwareLogger(ctx)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	logger.Info("add handler hit")
	query := r.URL.Query()
	op1String := query.Get("op1")
	op1, err := validateOp(ctx, op1String)
	if err != nil {
		setSpanError(span, "op1 validation failed", err, attribute.String("op1", op1String))
		logger.Error("op1 validation failed", slog.String("err", err.Error()), slog.String("op1String", op1String))
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
		logger.Error("op2 validation failed", slog.String("err", err.Error()), slog.String("op2String", op1String))
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}

	result := op1 + op2
	logger.Debug("making call to validate result")
	if err := validateAdd(ctx, logger, op1, op2, result); err != nil {
		errMsg := "add result validation failed"
		setSpanError(span, errMsg, err)
		logger.Error(errMsg, slog.String("err", err.Error()))
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("verification failed"))
		return
	}
	logger.Debug("operation complete")
	w.Write([]byte(strconv.Itoa(result)))
}

func validateAdd(ctx context.Context, logger *slog.Logger, op1, op2, sum int) error {
	// VERIFY_SERVICE_URL
	domain := envOrDefault("VERIFY_SERVICE_URL", "http://localhost:8000")

	ctx, span := tracer.Start(ctx, "validateAdd")
	defer span.End()

	url := fmt.Sprintf("%s/api/verify?op1=%d&op2=%d&es=%d", domain, op1, op2, sum)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		setSpanError(span, "failed to create request to verify service", err)
		return err
	}
	client := http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
	}
	res, err := client.Do(req)
	if err != nil {
		setSpanError(span, "failed to make request to verify service", err)
		return err
	}
	defer res.Body.Close()
	data, err := io.ReadAll(res.Body)
	if err != nil {
		setSpanError(span, "failed to read body from verify srervice request response", err)
		return err
	}
	type verifyServiceResponse struct {
		IsTrue bool `json:"isTrue"`
	}
	var result verifyServiceResponse
	if err := json.Unmarshal(data, &result); err != nil {
		setSpanError(span, "failed to unmarshal json response body from verify service", err)
		return err
	}
	if !result.IsTrue {
		err := fmt.Errorf("verify service determined that the operation was not correct...")
		setSpanError(span, "result was not correct", err)
		return err
	}
	return nil
}

// A simple health check handler
func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Println("healthcheck hit")
	w.WriteHeader(http.StatusOK)
}

func getTraceAwareLogger(spanContextWithLogger context.Context) (*slog.Logger, error) {
	logger, ok := spanContextWithLogger.Value(loggerKey).(*slog.Logger)
	if !ok {
		return nil, errors.New("request context did not contain a logger")
	}
	spanCtx := apptrace.SpanContextFromContext(spanContextWithLogger)
	if spanCtx.IsValid() {
		logger = logger.With(
			slog.String("traceID", spanCtx.TraceID().String()),
			slog.String("spanID", spanCtx.SpanID().String()),
		)
	}
	return logger, nil
}

func addLoggerMiddleware(next http.Handler, logger *slog.Logger) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := context.WithValue(r.Context(), loggerKey, logger)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func main() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		AddSource: true,
		Level:     slog.LevelDebug,
	}))
	logger.Debug("mathservice starting")
	if err := initTracing(ctx); err != nil {
		logger.Error("init traces errored", slog.String("err", err.Error()))
		// fmt.Printf("init traces errored: %v", err)
		return
	}
	if err := initMetrics(ctx); err != nil {
		logger.Error("init metrics errored", slog.String("err", err.Error()))
		// fmt.Printf("init metrics errored: %v", err)
		return
	}
	fmt.Println("starting up mathservice")
	mux := http.NewServeMux()
	mux.Handle("GET /add", otelhttp.NewHandler(addLoggerMiddleware(http.HandlerFunc(addHandler), logger), "add"))
	mux.HandleFunc("GET /health", healthCheckHandler)
	if err := http.ListenAndServe(":8080", mux); err != nil {
		fmt.Printf("HTTP server errored... %v", err)
	}
}
