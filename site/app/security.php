<?php
// Saída segura, CSRF e utilitários de entrada.

if (!function_exists('e')) {
    function e(mixed $value): string
    {
        return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
}

if (!function_exists('csrf_token')) {
    function csrf_token(): string
    {
        if (empty($_SESSION['csrf']) || !is_string($_SESSION['csrf'])) {
            $_SESSION['csrf'] = bin2hex(random_bytes(32));
        }
        return $_SESSION['csrf'];
    }
}

if (!function_exists('csrf_field')) {
    function csrf_field(): string
    {
        return '<input type="hidden" name="_csrf" value="' . e(csrf_token()) . '">';
    }
}

if (!function_exists('csrf_check')) {
    function csrf_check(): bool
    {
        $sent = $_POST['_csrf'] ?? '';
        if (!is_string($sent)) {
            $sent = '';
        }
        $stored = $_SESSION['csrf'] ?? '';
        if (!is_string($stored) || $stored === '') {
            return false;
        }
        return hash_equals($stored, $sent);
    }
}

if (!function_exists('post_str')) {
    // Devolve '' se ausente ou não-string (ex.: array). SEM trim, SEM corte.
    function post_str(string $key): string
    {
        $v = $_POST[$key] ?? '';
        return is_string($v) ? $v : '';
    }
}
