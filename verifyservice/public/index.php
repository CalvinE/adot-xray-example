<?php

use GuzzleHttp\Client;
use GuzzleHttp\Psr7\HttpFactory;
use Illuminate\Http\Request;
use Monolog\Handler\StreamHandler;
use Monolog\Logger;
use OpenTelemetry\API\Instrumentation\Configurator;
use OpenTelemetry\API\Signals;
use OpenTelemetry\Aws\Ecs\DataProvider;
use OpenTelemetry\Aws\Ecs\Detector;
use OpenTelemetry\Aws\Xray\IdGenerator;
use OpenTelemetry\Aws\Xray\Propagator;
use OpenTelemetry\Contrib\Grpc\GrpcTransportFactory;
use OpenTelemetry\Contrib\Otlp\OtlpUtil;
use OpenTelemetry\Contrib\Otlp\SpanExporter;
use OpenTelemetry\SDK\Common\Util\ShutdownHandler;
use OpenTelemetry\SDK\Logs\Exporter\ConsoleExporterFactory;
use OpenTelemetry\SDK\Logs\LoggerProvider;
use OpenTelemetry\SDK\Logs\Processor\SimpleLogRecordProcessor;
use OpenTelemetry\SDK\Trace\SpanProcessor\SimpleSpanProcessor;
use OpenTelemetry\SDK\Trace\TracerProvider;
use OpenTelemetry\SDK\Metrics\Meter;
use OpenTelemetry\API\Metrics;
use OpenTelemetry\Contrib\Otlp\MetricExporter;
use OpenTelemetry\SDK\Metrics\MeterProvider;
use OpenTelemetry\SDK\Metrics\MeterProviderBuilder;
use OpenTelemetry\SDK\Metrics\MetricReader\ExportingReader;
use OpenTelemetry\SDK\Metrics\MetricSourceProviderInterface;
use OpenTelemetry\SDK\Resource\ResourceInfo;
use OpenTelemetry\SDK\Resource\ResourceInfoFactory;
use OpenTelemetry\SDK\Trace\IdGeneratorInterface;
use OpenTelemetry\SDK\Trace\TracerProviderInterface;
use Psr\Log\LogLevel;

define('LARAVEL_START', microtime(true));

// Determine if the application is in maintenance mode...
if (file_exists($maintenance = __DIR__ . '/../storage/framework/maintenance.php')) {
    require $maintenance;
}

// Register the Composer autoloader...
require __DIR__ . '/../vendor/autoload.php';

function getResourceInfo()
{
    $client = new Client();
    $requestFactory = new HttpFactory();

    // ECS Detector
    $ecsDetectorDataProvider = new OpenTelemetry\Aws\Ecs\DataProvider();
    $ecsDetector = new OpenTelemetry\Aws\Ecs\Detector($ecsDetectorDataProvider, $client, $requestFactory);
    $ecsResourceInfo = $ecsDetector->getResource();
    if ($ecsResourceInfo->getAttributes()->count() > 0) {
        // ECS Resource was created!
        return $ecsResourceInfo;
    }

    // If not ECS try EC2?
    $ec2Detector = new OpenTelemetry\Aws\Ec2\Detector($client, $requestFactory);
    $ec2ResourceInfo = $ec2Detector->getResource();
    if ($ec2ResourceInfo->getAttributes()->count() > 0) {
        // ECS Resource was created!
        return $ec2ResourceInfo;
    }

    // Can also check for EKS!

    // All else fails lers create resource info.
    $manualResource = ResourceInfoFactory::defaultResource();
    return $manualResource;
}

function getTraceProvider(ResourceInfo $resourceInfo, IdGeneratorInterface $idGenerator): TracerProviderInterface
{
    $traceEndpoint = env("TRACE_TELEMETRY_ENDPOINT", "http://0.0.0.0:4317");
    $transport = (new GrpcTransportFactory())->create($traceEndpoint . OtlpUtil::method(Signals::TRACE));
    $exporter = new SpanExporter($transport);
    $spanProcessor = new SimpleSpanProcessor($exporter);

    $traceProvider = new TracerProvider($spanProcessor, null, $resourceInfo, null, $idGenerator);

    ShutdownHandler::register([$traceProvider, 'shutdown']);

    return $traceProvider;
}

function getMetricProvider(ResourceInfo $resourceInfo): OpenTelemetry\sdk\metrics\MeterProviderInterface
{
    $metricEndpoint = env("METRIC_TELEMETRY_ENDPOINT", "http://0.0.0.0:4317");
    $metricTransport = (new GrpcTransportFactory())->create($metricEndpoint . OtlpUtil::method(Signals::METRICS));
    $metricExporter = new MetricExporter($metricTransport);
    $metricReader = new ExportingReader($metricExporter);
    $meterProvider = MeterProvider::builder()
        ->setResource($resourceInfo)
        ->addReader($metricReader)
        ->build();

    ShutdownHandler::register([$meterProvider, 'shutdown']);

    return $meterProvider;
}

OpenTelemetry\API\Globals::registerInitializer(function (Configurator $configurator) {
    $idGenerator = new OpenTelemetry\Aws\Xray\IdGenerator();
    $propagator = new OpenTelemetry\Aws\Xray\Propagator();

    $resourceInfo = getResourceInfo();

    $traceProvider = getTraceProvider($resourceInfo, $idGenerator);

    // $logger = new Logger('verifyservice', [new StreamHandler(STDOUT, LogLevel::DEBUG)]);
    // log level filtering is handled in the collector...
    // $loggingProvider = LoggerProvider::builder()
    //     ->addLogRecordProcessor(
    //         new SimpleLogRecordProcessor(
    //             (new ConsoleExporterFactory())->create()
    //         )
    //     )
    //     ->setResource($resourceInfo)
    //     ->build();
    //
    // ShutdownHandler::register([$loggingProvider, 'shutdown']);

    $meterProvider = getMetricProvider($resourceInfo);

    return $configurator
        ->withPropagator($propagator)
        ->withTracerProvider($traceProvider)
        ->withMeterProvider($meterProvider);
    // ->withLoggerProvider($loggingProvider);
});

// Bootstrap Laravel and handle the request...
(require_once __DIR__ . '/../bootstrap/app.php')
    ->handleRequest(Request::capture());
