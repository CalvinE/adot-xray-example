<?php

use App\Http\Controllers\VerifyController;
use Illuminate\Support\Facades\Route;

Route::get('/api/verify', [VerifyController::class, 'verify']);

Route::get('/', function () {
    return view('welcome');
});
