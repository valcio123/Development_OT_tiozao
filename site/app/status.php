<?php
// Status do servidor: online/offline (TCP com cache de 30 s) + dados do banco.

if (!function_exists('server_status_online')) {
    function server_status_online(): bool
    {
        $path = STORAGE_DIR . '/cache/status.json';
        $ttl = (int)config('status_cache_ttl', 30);

        if (is_file($path)) {
            $data = json_decode((string)@file_get_contents($path), true);
            if (is_array($data) && isset($data['time'], $data['online']) && (time() - (int)$data['time']) < $ttl) {
                return (bool)$data['online'];
            }
        }

        $online = false;
        $fp = @fsockopen(
            (string)config('status_host', '127.0.0.1'),
            (int)config('status_port', 7171),
            $errno,
            $errstr,
            (float)config('status_timeout', 1.0)
        );
        if (is_resource($fp)) {
            $online = true;
            fclose($fp);
        }

        $tmp = $path . '.tmp';
        if (@file_put_contents($tmp, json_encode(['time' => time(), 'online' => $online])) !== false) {
            @rename($tmp, $path);
        } else {
            app_log('WARNING', 'status cache não gravável');
        }

        return $online;
    }
}

if (!function_exists('server_status')) {
    /**
     * @return array{online:bool,players:?int,record:?int,version:string}
     */
    function server_status(): array
    {
        $online = server_status_online();
        $players = null;
        $record = null;

        try {
            $players = (int)db()->query('SELECT COUNT(*) FROM players_online')->fetchColumn();
            $stmt = db()->prepare("SELECT value FROM server_config WHERE config = 'players_record' LIMIT 1");
            $stmt->execute();
            $val = $stmt->fetchColumn();
            if ($val !== false && $val !== null) {
                $record = (int)$val;
            }
        } catch (Throwable $e) {
            app_log('ERROR', 'status widget falhou', ['class' => get_class($e)]);
        }

        return [
            'online'  => $online,
            'players' => $players,
            'record'  => $record,
            'version' => (string)config('client_version', ''),
        ];
    }
}
