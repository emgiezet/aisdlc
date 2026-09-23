<?php

class UserController extends Controller
{
    public function store(Request $request)
    {
        // ok: slopguard.php.laravel.mass-assignment-request-all
        $validated = $request->validated();
        $user = User::create($validated);

        // ok: slopguard.php.laravel.mass-assignment-request-all
        $user->fill($request->only(['name', 'email']));

        return response()->json($user);
    }
}

class User extends Model
{
    protected $fillable = ['name', 'email', 'role'];
}
