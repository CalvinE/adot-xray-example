package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strconv"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	appmetric "go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"
)

func (mshh *mathServiceHTTPHandler) getVerifyServiceHttpURL(ctx context.Context, logger *slog.Logger) string {
	_, span := mshh.Tracer.Start(ctx, "getVerifyServiceHttpURL")
	defer span.End()
	psd, ok := os.LookupEnv("PSD_DOMAIN")
	if ok {
		domain := fmt.Sprintf("http://http-verifyservice.%s", psd)
		logger.Debug("PSD_DOMAIN so service connect is enabled", slog.String("psd_domain", psd), slog.String("domain", domain))
		return domain
	}
	domain := envOrDefault("VERIFY_SERVICE_URL", "http://localhost:8000")
	logger.Debug("service connect not found", slog.String("domain", domain))
	return domain
}

type mathServiceHTTPHandler struct {
	// we can add our meters here so we can reference them in our handler.
	Tracer                 trace.Tracer
	Meter                  appmetric.Meter
	NegativeOperandCounter appmetric.Int64Counter
	TotalOverallSum        appmetric.Int64UpDownCounter
}

func newMathServiceHTTPHandler() (mathServiceHTTPHandler, error) {
	meter := otel.Meter("MathService/AddHandler")
	negativeOperandCounter, err := meter.Int64Counter("NegativeOperandsProvided",
		appmetric.WithDescription("A count of the number of negative operands provided to the add method."),
	)
	if err != nil {
		return mathServiceHTTPHandler{}, fmt.Errorf("Falied to create NegativeOperandsProvided metric: %w", err)
	}

	totalOverallSum, err := meter.Int64UpDownCounter("TotalOverallSum",
		appmetric.WithDescription("The cumulative over all sum af all sums calculated by the AddHandler endpoint"),
	)
	if err != nil {
		return mathServiceHTTPHandler{}, fmt.Errorf("Falied to create TotalOverallSum metric: %w", err)
	}

	tracer := otel.Tracer("MathService") // tp.Tracer("adot-demo/mathservice")

	return mathServiceHTTPHandler{
		Tracer:                 tracer,
		Meter:                  meter,
		NegativeOperandCounter: negativeOperandCounter,
		TotalOverallSum:        totalOverallSum,
	}, nil
}

func (mshh *mathServiceHTTPHandler) RegisterHandlers(mux *http.ServeMux, logger *slog.Logger) error {
	mux.Handle("GET /add",
		otelhttp.NewHandler(
			addLoggerMiddleware(http.HandlerFunc(mshh.addHandler), logger), "add",
			otelhttp.WithMeterProvider(otel.GetMeterProvider()),
			otelhttp.WithTracerProvider(otel.GetTracerProvider()),
		),
	)
	return nil
}

func (mshh *mathServiceHTTPHandler) addHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := mshh.Tracer.Start(r.Context(), "addHandler") // tracer.Start(r.Context(), "addHandler")
	defer span.End()
	logger, err := getTraceAwareLogger(ctx)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	logger.Info("add handler hit")
	query := r.URL.Query()
	op1String := query.Get("op1")
	op1, err := mshh.validateOp(ctx, op1String)
	if err != nil {
		setSpanError(span, "op1 validation failed", err, attribute.String("op1", op1String))
		logger.Error("op1 validation failed", slog.String("err", err.Error()), slog.String("op1String", op1String))
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}
	if op1 < 0 {
		mshh.NegativeOperandCounter.Add(ctx, 1,
			appmetric.WithAttributes(
				attribute.String("operand", "op1"),
			),
		)
	}
	op2String := query.Get("op2")
	op2, err := mshh.validateOp(ctx, op2String)
	if err != nil {
		setSpanError(span, "op2 validation failed", err, attribute.String("op2", op2String))
		logger.Error("op2 validation failed", slog.String("err", err.Error()), slog.String("op2String", op1String))
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}
	if op2 < 0 {
		mshh.NegativeOperandCounter.Add(ctx, 1,
			appmetric.WithAttributes(
				attribute.String("operand", "op2"),
			),
		)
	}

	result := op1 + op2
	mshh.TotalOverallSum.Add(ctx, int64(result))
	logger.Debug("making call to validate result")
	if err := mshh.validateAdd(ctx, logger, op1, op2, result); err != nil {
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

func (mshh *mathServiceHTTPHandler) validateOp(ctx context.Context, op string) (int, error) {
	_, span := mshh.Tracer.Start(ctx, "validateOp")
	defer span.End()
	val, err := strconv.Atoi(op)
	if err != nil {
		setSpanError(span, "failed to validate operand", err, attribute.String("operand", op), attribute.String("err", err.Error()))
		return 0, err
	}
	return val, nil
}

func (mshh *mathServiceHTTPHandler) validateAdd(ctx context.Context, logger *slog.Logger, op1, op2, sum int) error {
	ctx, span := mshh.Tracer.Start(ctx, "validateAdd")
	defer span.End()
	logger.Debug("calling verify service to verify result")
	domain := mshh.getVerifyServiceHttpURL(ctx, logger)
	url := fmt.Sprintf("%s/api/verify?op1=%d&op2=%d&es=%d", domain, op1, op2, sum)
	logger.Info("constructed verify url", slog.String("url", url))
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
