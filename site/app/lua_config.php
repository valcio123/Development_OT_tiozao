<?php
// Leitor das credenciais de banco a partir do config.lua do Canary.
// A senha NUNCA aparece em log nem em mensagem de exceção: só o nome da chave.

if (!function_exists('parse_lua_db_config')) {
    /**
     * @return array{host:string,user:string,password:string,database:string,port:int}
     */
    function parse_lua_db_config(string $path): array
    {
        if (!is_file($path) || !is_readable($path)) {
            throw new RuntimeException('config.lua: arquivo ausente');
        }

        $raw = @file_get_contents($path);
        if ($raw === false) {
            throw new RuntimeException('config.lua: arquivo ilegível');
        }

        $lines = preg_split('/\r\n|\r|\n/', $raw) ?: [];
        $found = [];

        $pattern = '/^\s*(mysqlHost|mysqlUser|mysqlPass|mysqlDatabase|mysqlPort)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|(\d+))/';
        foreach ($lines as $line) {
            $trim = ltrim($line);
            if ($trim === '' || str_starts_with($trim, '--')) {
                continue;
            }
            if (preg_match($pattern, $line, $m)) {
                $key = $m[1];
                if (isset($m[2]) && $m[2] !== '') {
                    $value = $m[2];
                } elseif (isset($m[3]) && $m[3] !== '') {
                    $value = $m[3];
                } else {
                    $value = $m[4] ?? '';
                }
                // Primeira ocorrência vence.
                if (!array_key_exists($key, $found)) {
                    $found[$key] = $value;
                }
            }
        }

        if (!isset($found['mysqlHost']) || $found['mysqlHost'] === '') {
            throw new RuntimeException('config.lua: chave mysqlHost ausente');
        }
        if (!isset($found['mysqlUser']) || $found['mysqlUser'] === '') {
            throw new RuntimeException('config.lua: chave mysqlUser ausente');
        }
        if (!isset($found['mysqlDatabase']) || $found['mysqlDatabase'] === '') {
            throw new RuntimeException('config.lua: chave mysqlDatabase ausente');
        }

        $port = 3306;
        if (isset($found['mysqlPort']) && $found['mysqlPort'] !== '') {
            $port = (int)$found['mysqlPort'];
        }

        return [
            'host'     => (string)$found['mysqlHost'],
            'user'     => (string)$found['mysqlUser'],
            'password' => (string)($found['mysqlPass'] ?? ''),
            'database' => (string)$found['mysqlDatabase'],
            'port'     => $port,
        ];
    }
}
