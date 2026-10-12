<?php
// Rate limit por IP, baseado em arquivos (fora do webroot). Núcleo testável com
// diretório e parâmetros explícitos + wrappers que leem a config do site.

if (!function_exists('rl_path')) {
    function rl_path(string $dir, string $bucket, string $ip): string
    {
        return rtrim($dir, '/\\') . DIRECTORY_SEPARATOR . hash('sha256', $bucket . '|' . $ip) . '.json';
    }

    function rl_open(string $file)
    {
        $fh = @fopen($file, 'c+');
        if ($fh === false) {
            return null;
        }
        if (!@flock($fh, LOCK_EX)) {
            fclose($fh);
            return null;
        }
        return $fh;
    }

    function rl_load($fh, int $window, int $now): array
    {
        rewind($fh);
        $raw = stream_get_contents($fh);
        $arr = json_decode((string)$raw, true);
        if (!is_array($arr)) {
            $arr = [];
        }
        $min = $now - $window;
        $out = [];
        foreach ($arr as $t) {
            if (is_int($t) && $t >= $min) {
                $out[] = $t;
            }
        }
        return $out;
    }

    function rl_save($fh, array $ts): void
    {
        rewind($fh);
        ftruncate($fh, 0);
        fwrite($fh, json_encode(array_values($ts)));
        fflush($fh);
    }

    function rl_close($fh): void
    {
        @flock($fh, LOCK_UN);
        fclose($fh);
    }

    function rl_exceeded_at(string $dir, string $bucket, string $ip, int $max, int $window, ?int $now = null): bool
    {
        $now ??= time();
        $fh = rl_open(rl_path($dir, $bucket, $ip));
        if ($fh === null) {
            return false; // fail-open
        }
        $ts = rl_load($fh, $window, $now);
        $exceeded = count($ts) >= $max;
        rl_save($fh, $ts);
        rl_close($fh);
        return $exceeded;
    }

    function rl_hit_at(string $dir, string $bucket, string $ip, int $window, ?int $now = null): void
    {
        $now ??= time();
        $fh = rl_open(rl_path($dir, $bucket, $ip));
        if ($fh === null) {
            return;
        }
        $ts = rl_load($fh, $window, $now);
        $ts[] = $now;
        rl_save($fh, $ts);
        rl_close($fh);
    }

    function rl_clear_at(string $dir, string $bucket, string $ip): void
    {
        $file = rl_path($dir, $bucket, $ip);
        if (is_file($file)) {
            @unlink($file);
        }
    }

    function rl_retry_after_at(string $dir, string $bucket, string $ip, int $max, int $window, ?int $now = null): int
    {
        $now ??= time();
        $fh = rl_open(rl_path($dir, $bucket, $ip));
        if ($fh === null) {
            return 0;
        }
        $ts = rl_load($fh, $window, $now);
        rl_close($fh);
        if (count($ts) < $max) {
            return 0;
        }
        $oldest = min($ts);
        return max(0, ($oldest + $window) - $now);
    }
}

if (!function_exists('rl_dir')) {
    function rl_dir(): string
    {
        $dir = STORAGE_DIR . '/ratelimit';
        if (!is_dir($dir)) {
            @mkdir($dir, 0700, true);
        }
        return $dir;
    }

    function rl_limits(string $bucket): array
    {
        return (array)config($bucket === 'register' ? 'register_limit' : 'login_limit');
    }

    function rl_ready(string $bucket): bool
    {
        $dir = rl_dir();
        if (!is_writable($dir)) {
            app_log('ERROR', 'ratelimit indisponível', ['bucket' => $bucket]);
            return false;
        }
        return true;
    }

    function rl_exceeded(string $bucket, string $ip): bool
    {
        if (!rl_ready($bucket)) {
            return false;
        }
        $l = rl_limits($bucket);
        return rl_exceeded_at(rl_dir(), $bucket, $ip, (int)$l['max'], (int)$l['window']);
    }

    function rl_hit(string $bucket, string $ip): void
    {
        if (!rl_ready($bucket)) {
            return;
        }
        $l = rl_limits($bucket);
        rl_hit_at(rl_dir(), $bucket, $ip, (int)$l['window']);
    }

    function rl_clear(string $bucket, string $ip): void
    {
        rl_clear_at(rl_dir(), $bucket, $ip);
    }

    function rl_retry_after(string $bucket, string $ip): int
    {
        if (!rl_ready($bucket)) {
            return 0;
        }
        $l = rl_limits($bucket);
        return rl_retry_after_at(rl_dir(), $bucket, $ip, (int)$l['max'], (int)$l['window']);
    }
}
