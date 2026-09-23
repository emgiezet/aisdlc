<?php
// ok: slopguard.php.laravel.blade-unescaped-output
// Use escaped output for user data; {!! !!} only for verified-safe HTML
?>
<div>{{ $userBio }}</div>
<h1>{{ $title }}</h1>
{{-- Unescaped only for content from a trusted sanitizer, never raw user input --}}
<p>{!! $sanitizedHtml !!}</p>
