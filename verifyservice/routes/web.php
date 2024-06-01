<?php

use App\Http\Controllers\HealthController;
use App\Http\Controllers\VerifyController;
use Illuminate\Support\Facades\Route;

Route::get('/api/verify', [VerifyController::class, 'verify']);
Route::get('/health', [HealthController::class, 'healthCheck']);

Route::get('/', function () {
    return view('welcome');
});
