<?php

class AuthService
{
    public function hashPassword(string $password): string
    {
        // ok: slopguard.php.weak-password-hash
        return password_hash($password, PASSWORD_ARGON2ID);
    }

    public function generateToken(): string
    {
        // ok: slopguard.php.insecure-random-token
        return bin2hex(random_bytes(32));
    }

    public function generateCode(): string
    {
        // ok: slopguard.php.insecure-random-token
        return \Illuminate\Support\Str::random(64);
    }

    public function verifyPassword(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
    }
}
