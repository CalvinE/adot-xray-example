<?php

namespace App\Http\Controllers;

use Exception;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Log;
use OpenTelemetry\API\Instrumentation\CachedInstrumentation;
use OpenTelemetry\API\Logs\LogRecord;
use OpenTelemetry\API\Trace\Span;
use OpenTelemetry\API\Trace\StatusCode;
use Psr\Log\LogLevel;

class VerifyController extends Controller
{
    public function verify(Request $request, Response $response): Response
    {
        $instrumentation = new CachedInstrumentation("VerifyService/VerifyHandler");
        // $logger = $instrumentation->logger();
        $span = $instrumentation->tracer()->spanBuilder("verify")->startSpan();
        // $span = Span::getCurrent();
        $traceId = $span->getContext()->getTraceId();
        Log::debug("in the verify endpoint", ["traceId" => $traceId]);
        // $logger->emit((new LogRecord())
        //     ->setBody("in the verify endpoint")
        //     ->setAttribute("traceId", $traceId)
        //     ->setSeverityText(LogLevel::DEBUG));
        try {
            $op1 = (int)$request->query("op1");
            $op2 = (int)$request->query("op2");
            $expectedSum = (int)$request->query("es");

            $sum = $op1 + $op2;

            $span->setAttributes(["op1" => $op1, "op2" => $op2, "expectedSum" => $expectedSum, "sum" => $sum]);

            if ($sum === 8) {
                throw new Exception("I dont like the number 8...");
            }

            $isCorrect = $sum === $expectedSum;

            return response(["isTrue" => $isCorrect], 200)->header('Content-Type', "application/json");
        } catch (Exception $exception) {
            Log::debug("an error occurred", ["traceId" => $traceId, "error" => $exception->getMessage(), "stackTrace" => $exception->getTraceAsString()]);
            $meter = $instrumentation->meter()->createHistogram("exceptions", "occurances", "The number of exceptions that have occurred");
            $meter->record(1);
            // $logger->emit((new LogRecord())
            //     ->setBody("an error happened")
            //     ->setAttribute("traceId", $traceId)
            //     ->setSeverityText(LogLevel::ERROR));
            $span->setStatus(StatusCode::STATUS_ERROR);
            $span->recordException($exception);
            return response(null, 500);
        } finally {
            $span->end();
        }
    }
}
