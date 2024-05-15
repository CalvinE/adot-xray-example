<?php

use OpenTelemetry\API\Trace\SpanKind;
// use OpenTelemetry\API\Signals;
use OpenTelemetry\API\Common\Signal\Signals;
use OpenTelemetry\API\LoggerHolder;

use OpenTelemetry\Contrib\Otlp\OtlpUtil;
use OpenTelemetry\Contrib\Otlp\SpanExporter;
use OpenTelemetry\Contrib\Grpc\GrpcTransportFactory;

use OpenTelemetry\Aws\Xray\IdGenerator;
use OpenTelemetry\Aws\Xray\Propagator;
use OpenTelemetry\Aws\AwsSdkInstrumentation;

use OpenTelemetry\SDK\Common\Configuration\Configuration;
use OpenTelemetry\SDK\Common\Configuration\Variables;
use OpenTelemetry\SDK\Trace\TracerProvider;
use OpenTelemetry\SDK\Trace\SpanProcessor\SimpleSpanProcessor;
use OpenTelemetry\API\Globals;
use OpenTelemetry\API\Logs\EventLogger;
use OpenTelemetry\API\Logs\LogRecord;
use OpenTelemetry\API\Trace\Propagation\TraceContextPropagator;
use OpenTelemetry\Contrib\Otlp\LogsExporter;
use OpenTelemetry\Contrib\Otlp\MetricExporter;
use OpenTelemetry\SDK\Common\Attribute\Attributes;
use OpenTelemetry\SDK\Common\Export\Stream\StreamTransportFactory;
use OpenTelemetry\SDK\Logs\LoggerProvider;
use OpenTelemetry\SDK\Logs\Processor\SimpleLogRecordProcessor;
use OpenTelemetry\SDK\Metrics\MeterProvider;
use OpenTelemetry\SDK\Metrics\MetricReader\ExportingReader;
use OpenTelemetry\SDK\Resource\ResourceInfo;
use OpenTelemetry\SDK\Resource\ResourceInfoFactory;
use OpenTelemetry\SDK\Sdk;
use OpenTelemetry\SDK\Trace\Sampler\AlwaysOnSampler;
use OpenTelemetry\SDK\Trace\Sampler\ParentBased;
use OpenTelemetry\SemConv\ResourceAttributes;

require 'vendor/autoload.php';

$resource = ResourceInfoFactory::emptyResource()->merge(ResourceInfo::create(Attributes::create([
  ResourceAttributes::SERVICE_NAMESPACE => 'adot-demo',
  ResourceAttributes::SERVICE_NAME => 'verifyservice',
  ResourceAttributes::SERVICE_VERSION => '0.1',
  ResourceAttributes::DEPLOYMENT_ENVIRONMENT => 'development',
])));
// Initialize Span Processor, X-Ray ID generator, Tracer Provider, and Propagator
$otplUtil = new OtlpUtil();
$transport = (new GrpcTransportFactory())->create('http://0.0.0.0:4317' . OtlpUtil::method(Signals::TRACE));
$spanExporter = new SpanExporter($transport);
$spanProcessor = new SimpleSpanProcessor($spanExporter);

$idGenerator = new IdGenerator();
$tracerProvider = new TracerProvider($spanProcessor, null, null, null, $idGenerator);
$propagator = TraceContextPropagator::getInstance();
$tracer = $tracerProvider->getTracer('io.opentelemetry.contrib.php');

// $logExporter = new LogsExporter(
//   (new StreamTransportFactory())->create('php://stdout', 'application/json')
// );

// $reader = new ExportingReader(
//   new MetricExporter(
//     (new StreamTransportFactory())->create('php://stdout', 'application/json')
//   )
// );
//
// $meterProvider = MeterProvider::builder()
//   ->setResource($resource)
//   ->addReader($reader)
//   ->build();

$tracerProvider = TracerProvider::builder()
  ->addSpanProcessor(
    new SimpleSpanProcessor($spanExporter)
  )
  ->setResource($resource)
  ->setSampler(new ParentBased(new AlwaysOnSampler()))
  ->build();

// $loggerProvider = LoggerProvider::builder()
//   ->setResource($resource)
//   ->addLogRecordProcessor(
//     new SimpleLogRecordProcessor($logExporter)
//   )
//   ->build();

Sdk::builder()
  ->setTracerProvider($tracerProvider)
  // ->setMeterProvider($meterProvider)
  // ->setLoggerProvider($loggerProvider)
  ->setPropagator($propagator)
  ->setAutoShutdown(true)
  ->buildAndRegisterGlobal();
