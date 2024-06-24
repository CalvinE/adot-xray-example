package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"

	apptrace "go.opentelemetry.io/otel/trace"
)

func envOrDefault(name string, defaultValue string) string {
	if val, exists := os.LookupEnv(name); exists {
		return val
	}
	return defaultValue
}

func getTraceAwareLogger(spanContextWithLogger context.Context) (*slog.Logger, error) {
	logger, ok := spanContextWithLogger.Value(loggerKey).(*slog.Logger)
	if !ok {
		return nil, errors.New("context did not contain a logger")
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
	res, err := getResourceInfo(ctx)
	if err != nil {
		logger.Error("failed to get resource info", slog.String("err", err.Error()))
		return
	}
	traceShutdown, err := initTracing(ctx, res)
	if err != nil {
		logger.Error("init traces errored", slog.String("err", err.Error()))
		// fmt.Printf("init traces errored: %v", err)
		return
	}
	defer traceShutdown(ctx)
	metricShutdown, err := initMetrics(ctx, res)
	if err != nil {
		logger.Error("init metrics errored", slog.String("err", err.Error()))
		// fmt.Printf("init metrics errored: %v", err)
		return
	}
	defer metricShutdown(ctx)
	fmt.Println("starting up mathservice")
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", healthCheckHandler)
	mshh, err := newMathServiceHTTPHandler()
	if err != nil {
		logger.Error("failed to create the math service http handler", slog.String("err", err.Error()))
		return
	}
	if err := mshh.RegisterHandlers(mux, logger); err != nil {
		logger.Error("failed to add math service handlers", slog.String("err", err.Error()))
	}
	if err := http.ListenAndServe(":8080", mux); err != nil {
		fmt.Printf("HTTP server errored... %v", err)
	}
}
