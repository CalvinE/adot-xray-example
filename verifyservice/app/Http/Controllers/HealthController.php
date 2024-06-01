<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\Response;

class HealthController extends Controller
{
    //
    public function healthCheck(): Response
    {
        return response('', 200);
    }
}
