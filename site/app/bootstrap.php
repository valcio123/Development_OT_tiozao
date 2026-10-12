<?php
declare(strict_types=1);

// Bootstrap do site próprio do TiozaoOT.
// Config, log, sessão, CSRF e headers. Toda página em public/ require este arquivo.

define('SITE_ROOT', dirname(__DIR__));
define('APP_DIR', SITE_ROOT . '/app');
define('STORAGE_DIR', SITE_ROOT . '/storage');
define('LOG_DIR', STORAGE_DIR . '/logs');

// Diretórios de trabalho (fora do webroot).
foreach (['logs', 'sessions', 'ratelimit', 'cache'] as $__d) {
    $__p = STORAGE_DIR . '/' . $__d;
    if (!is_dir($__p)) {
        @mkdir($__p, 0700, true);
    }
}
unset($__d, $__p);

require_once APP_DIR . '/log.php';

// --- Configuração -----------------------------------------------------------
$__configPath = SITE_ROOT . '/config/config.php';
$config = is_file($__configPath) ? require $__configPath : null;

if (!is_array($config)) {
    app_log('CRITICAL', 'config.php ausente ou inválido');
    http_response_code(500);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">'
        . '<meta name="viewport" content="width=device-width, initial-scale=1">'
        . '<title>Erro</title></head><body>'
        . '<h1>Algo deu errado</h1><p>Tente novamente em instantes.</p></body></html>';
    exit;
}

$GLOBALS['__config'] = $config;
unset($__configPath, $config);

if (!function_exists('config')) {
    function config(string $key, mixed $default = null): mixed
    {
        return array_key_exists($key, $GLOBALS['__config']) ? $GLOBALS['__config'][$key] : $default;
    }
}

// Normalizações da config.
if (trim((string)config('server_name', '')) === '') {
    $GLOBALS['__config']['server_name'] = 'TiozaoOT';
}
$__download = (string)config('download_url', '');
if ($__download !== '' && !preg_match('#^https://#i', $__download)) {
    app_log('WARNING', 'download_url inválida');
    $GLOBALS['__config']['download_url'] = '';
}
unset($__download);

// --- Helpers ----------------------------------------------------------------
foreach (['lua_config', 'db', 'security', 'validation', 'vocations', 'ratelimit', 'auth', 'repo_accounts', 'repo_players', 'repo_news', 'status', 'layout'] as $__f) {
    require_once APP_DIR . '/' . $__f . '.php';
}
unset($__f);

// --- Erros e logs -----------------------------------------------------------
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');
ini_set('error_log', LOG_DIR . '/php-error.log');
date_default_timezone_set((string)config('timezone', 'UTC'));

set_exception_handler(function (Throwable $e): void {
    app_log('CRITICAL', 'exceção não tratada', [
        'class'   => get_class($e),
        'message' => $e->getMessage(),
        'at'      => $e->getFile() . ':' . $e->getLine(),
    ]);
    if (!headers_sent()) {
        http_response_code(500);
        header('Content-Type: text/html; charset=utf-8');
        echo '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">'
            . '<meta name="viewport" content="width=device-width, initial-scale=1">'
            . '<title>Erro</title></head><body>'
            . '<h1>Algo deu errado</h1><p>Tente novamente em instantes.</p></body></html>';
    } else {
        echo '<p>Algo deu errado. Tente novamente em instantes.</p>';
    }
});

// --- Sessão -----------------------------------------------------------------
if (session_status() === PHP_SESSION_NONE) {
    session_name('TIOZAOSID');
    session_save_path(STORAGE_DIR . '/sessions');
    ini_set('session.use_strict_mode', '1');
    ini_set('session.use_only_cookies', '1');
    ini_set('session.use_trans_sid', '0');
    ini_set('session.gc_maxlifetime', (string)config('session_idle', 7200));
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
        'secure'   => false,
    ]);
    session_start();
}

// --- Headers de segurança ---------------------------------------------------
if (!headers_sent()) {
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('Referrer-Policy: same-origin');
    header("Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'");
    header('Content-Type: text/html; charset=utf-8');
}

// --- CSRF global (todo POST) ------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST' && !csrf_check()) {
    app_log('INFO', 'csrf inválido', ['path' => $_SERVER['REQUEST_URI'] ?? '']);
    http_response_code(400);
    echo '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">'
        . '<meta name="viewport" content="width=device-width, initial-scale=1">'
        . '<title>Sessão expirada</title></head><body>'
        . '<h1>Sua sessão expirou</h1>'
        . '<p>Recarregue a página e tente de novo.</p></body></html>';
    exit;
}
