package main

import (
	"context"
	"fmt"

	"go.opentelemetry.io/contrib/detectors/aws/ecs"
	"go.opentelemetry.io/contrib/propagators/aws/xray"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.25.0"
	apptrace "go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
)

const loggerKey = "loggerKey"

// var tracer apptrace.Tracer

type ShutdownFunc func(context.Context) error

func getResourceInfo(ctx context.Context) (*resource.Resource, error) {
	var res *resource.Resource

	ecsResourceDetector := ecs.NewResourceDetector()
	res, err := ecsResourceDetector.Detect(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to build the ecs resource detector: %v", err)
	}
	if res != nil {
		return res, nil
	}
	// here we can look for ec2 or other automatic resource detectors.

	// fall back to manual resource dedinition?
	return resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(semconv.SchemaURL,
			semconv.ServiceName("MathService"),
		),
	)
}

func initTracing(ctx context.Context, res *resource.Resource) (ShutdownFunc, error) {
	// Create and start new OTLP trace exporter
	traceExporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithEndpoint("0.0.0.0:4317"),
		otlptracegrpc.WithDialOption(grpc.WithBlock()),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create new OTLP trace exporter: %v", err)
	}
	idg := xray.NewIDGenerator()

	tp := trace.NewTracerProvider(
		trace.WithSampler(trace.AlwaysSample()),
		trace.WithBatcher(traceExporter),
		trace.WithIDGenerator(idg),
		trace.WithResource(res),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(xray.Propagator{})

	// tracer = tp.Tracer("adot-demo/mathservice")

	return traceExporter.Shutdown, nil
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

func initMetrics(ctx context.Context, res *resource.Resource) (ShutdownFunc, error) {
	// Create and start new OTLP metric exporter
	metricExporter, err := otlpmetricgrpc.New(ctx,
		otlpmetricgrpc.WithInsecure(),
		otlpmetricgrpc.WithEndpoint("0.0.0.0:4317"),
		otlpmetricgrpc.WithDialOption(grpc.WithBlock()),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create new OTLP metric exporter: %v", err)
	}

	mp := metric.NewMeterProvider(
		metric.WithReader(metric.NewPeriodicReader(metricExporter)),
		metric.WithResource(res),
	)

	otel.SetMeterProvider(mp)

	return metricExporter.Shutdown, nil
}
