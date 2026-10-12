<?php
// Registro de eventos da aplicação. Grava em storage/logs/app.log (fora do webroot).
// REGRA: nunca registrar senha, hash de senha ou email.

if (!function_exists('app_log')) {
    function app_log(string $level, string $msg, array $ctx = []): void
    {
        if (!defined('LOG_DIR')) {
            return;
        }

        $ctx['ip'] = $ctx['ip'] ?? ($_SERVER['REMOTE_ADDR'] ?? '');
        if (!isset($ctx['account_id']) && isset($_SESSION['account_id'])) {
            $ctx['account_id'] = (int)$_SESSION['account_id'];
        }

        $line = sprintf(
            '[%s] %s %s %s%s',
            date('Y-m-d H:i:s'),
            strtoupper($level),
            $msg,
            $ctx === [] ? '' : json_encode($ctx, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            PHP_EOL
        );

        @file_put_contents(LOG_DIR . '/app.log', $line, FILE_APPEND | LOCK_EX);
    }
}
