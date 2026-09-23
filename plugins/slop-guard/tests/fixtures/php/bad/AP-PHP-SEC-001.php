<?php
// ruleid: slopguard.php.laravel.raw-sql-interpolation
$results = DB::select("SELECT * FROM users WHERE email = '" . $email . "'");

// ruleid: slopguard.php.laravel.raw-sql-interpolation
$users = User::whereRaw("status = '" . $status . "' AND role = 'user'")
    ->get();

// ruleid: slopguard.php.laravel.raw-sql-interpolation
$query = DB::raw("created_at > '" . $date . "'");
