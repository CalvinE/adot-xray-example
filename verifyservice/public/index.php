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
use OpenTelemetry\SDK\Resource\ResourceInfoFactory;
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
    // Can also check for Ec2 etc... can have if check on a getResource call and if empty get ec2 info...
    $detectorDataProvider = new DataProvider();
    $client = new Client();
    $requestFactory = new HttpFactory();
    // ECS Detector
    $detector = new Detector($detectorDataProvider, $client, $requestFactory);
    if ($detector != null) {
        return $detector->getResource();
    }

    // If not ECS try EC2?

    // All else fails lers create resource info.
    $manualResource = ResourceInfoFactory::defaultResource();
    return $manualResource;
}

OpenTelemetry\API\Globals::registerInitializer(function (Configurator $configurator) {
    $idGenerator = new IdGenerator();
    $propagator = new Propagator();

    $resourceInfo = getResourceInfo();

    $transport = (new GrpcTransportFactory())->create('http://0.0.0.0:4317' . OtlpUtil::method(Signals::TRACE));
    $exporter = new SpanExporter($transport);
    $spanProcessor = new SimpleSpanProcessor($exporter);

    $traceProvider = new TracerProvider($spanProcessor, null, $resourceInfo, null, $idGenerator);

    ShutdownHandler::register([$traceProvider, 'shutdown']);

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
    //
    $metricTransport = (new GrpcTransportFactory())->create('http://0.0.0.0:4317' . OtlpUtil::method(Signals::METRICS));
    $metricExporter = new MetricExporter($metricTransport);
    $metricReader = new ExportingReader($metricExporter);
    $meterProvider = MeterProvider::builder()
        ->setResource($resourceInfo)
        ->addReader($metricReader)
        ->build();

    ShutdownHandler::register([$meterProvider, 'shutdown']);

    return $configurator
        ->withPropagator($propagator)
        ->withTracerProvider($traceProvider)
        ->withMeterProvider($meterProvider);
    // ->withLoggerProvider($loggingProvider);
});

// Bootstrap Laravel and handle the request...
(require_once __DIR__ . '/../bootstrap/app.php')
    ->handleRequest(Request::capture());
