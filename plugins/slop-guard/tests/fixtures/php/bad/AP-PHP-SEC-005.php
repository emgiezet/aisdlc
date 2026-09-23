<?php

class UserController extends Controller
{
    public function store(Request $request)
    {
        // ruleid: slopguard.php.laravel.mass-assignment-request-all
        $user = User::create($request->all());

        // ruleid: slopguard.php.laravel.mass-assignment-request-all
        $user->fill($request->all());

        return response()->json($user);
    }
}
