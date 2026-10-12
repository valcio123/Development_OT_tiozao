<?php
// Conexão PDO com o banco `canary`. Lazy, singleton, com prepared statements.

if (!function_exists('db')) {
    function db(): PDO
    {
        static $pdo = null;
        static $failed = false;

        if ($pdo instanceof PDO) {
            return $pdo;
        }
        if ($failed) {
            // Já falhou nesta requisição: não tenta de novo.
            throw new RuntimeException('banco indisponível');
        }

        try {
            $cfg = parse_lua_db_config((string)config('canary_config_lua'));
            $dsn = sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
                $cfg['host'],
                $cfg['port'],
                $cfg['database']
            );
            $pdo = new PDO($dsn, $cfg['user'], $cfg['password'], [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_EMULATE_PREPARES   => false,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_TIMEOUT            => 3,
            ]);
        } catch (Throwable $e) {
            $failed = true;
            throw $e;
        }

        return $pdo;
    }
}
