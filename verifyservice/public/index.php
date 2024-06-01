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
use Psr\Log\LogLevel;

define('LARAVEL_START', microtime(true));

// Determine if the application is in maintenance mode...
if (file_exists($maintenance = __DIR__ . '/../storage/framework/maintenance.php')) {
    require $maintenance;
}

// Register the Composer autoloader...
require __DIR__ . '/../vendor/autoload.php';

OpenTelemetry\API\Globals::registerInitializer(function (Configurator $configurator) {
    $idGenerator = new IdGenerator();
    $propagator = new Propagator();

    $transport = (new GrpcTransportFactory())->create('http://0.0.0.0:4317' . OtlpUtil::method(Signals::TRACE));
    $exporter = new SpanExporter($transport);
    $spanProcessor = new SimpleSpanProcessor($exporter);

    // Can also check for Ec2 etc... can have if check on a getResource call and if empty get ec2 info...
    $detectorDataProvider = new DataProvider();
    $client = new Client();
    $requestFactory = new HttpFactory();
    $detector = new Detector($detectorDataProvider, $client, $requestFactory);
    $resourceInfo = $detector->getResource();
    // $logger = new Logger('verifyservice', [new StreamHandler(STDOUT, LogLevel::DEBUG)]);

    // TracerProviderFactory does not let you se the id generator?
    $traceProvider = new TracerProvider($spanProcessor, null, $resourceInfo, null, $idGenerator);

    ShutdownHandler::register([$traceProvider, 'shutdown']);

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

    return $configurator
        ->withPropagator($propagator)
        ->withTracerProvider($traceProvider);
    // ->withLoggerProvider($loggingProvider);
});

// Bootstrap Laravel and handle the request...
(require_once __DIR__ . '/../bootstrap/app.php')
    ->handleRequest(Request::capture());
