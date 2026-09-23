<?php
// ok: slopguard.php.laravel.raw-sql-interpolation
$results = DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// ok: slopguard.php.laravel.raw-sql-interpolation
$users = User::where('status', $status)
    ->where('role', 'user')
    ->get();

// ok: slopguard.php.laravel.raw-sql-interpolation
$users = User::whereRaw('created_at > ?', [$date])->get();
