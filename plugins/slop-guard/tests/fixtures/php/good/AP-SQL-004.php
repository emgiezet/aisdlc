<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // ok: slopguard.laravel.migration-fk-without-index
        Schema::table('orders', function (Blueprint $table) {
            // foreignId() creates the column + index + foreign key constraint together
            $table->foreignId('user_id')->constrained('users');
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
        });
    }
};
