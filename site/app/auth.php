<?php
// Autenticação e sessão da conta.

if (!function_exists('current_ip')) {
    function current_ip(): string
    {
        $ip = $_SERVER['REMOTE_ADDR'] ?? '';
        return is_string($ip) ? $ip : '';
    }
}

if (!function_exists('current_account')) {
    /**
     * Recarrega a conta da sessão a cada requisição. Devolve null se inválida.
     * @return array{id:int,email:string,type:int,password:string}|null
     */
    function current_account(): ?array
    {
        if (empty($_SESSION['account_id'])) {
            return null;
        }

        $id = (int)$_SESSION['account_id'];
        $stmt = db()->prepare('SELECT id, email, type, password FROM accounts WHERE id = ? LIMIT 1');
        $stmt->execute([$id]);
        $row = $stmt->fetch();

        if (!$row) {
            logout_account(false);
            return null;
        }

        $pwfp = hash('sha256', (string)$row['password']);
        if (!hash_equals((string)($_SESSION['pwfp'] ?? ''), $pwfp)) {
            logout_account(false);
            return null;
        }

        $idle = (int)config('session_idle', 7200);
        if ((int)($_SESSION['last'] ?? 0) + $idle < time()) {
            logout_account(false);
            return null;
        }

        $_SESSION['last'] = time();

        return [
            'id'       => (int)$row['id'],
            'email'    => (string)$row['email'],
            'type'     => (int)$row['type'],
            'password' => (string)$row['password'],
        ];
    }
}

if (!function_exists('login_account')) {
    /**
     * @return array{ok:bool,error:?string}
     */
    function login_account(string $email, string $password): array
    {
        $ip = current_ip();

        if (rl_exceeded('login', $ip)) {
            $mins = max(1, (int)ceil(rl_retry_after('login', $ip) / 60));
            return ['ok' => false, 'error' => "Muitas tentativas de login. Tente novamente em {$mins} minutos."];
        }

        $generic = 'Email ou senha incorretos.';
        $email = mb_substr(trim($email), 0, 255);
        if ($email === '' || mb_strlen($password, 'UTF-8') > 256) {
            rl_hit('login', $ip);
            return ['ok' => false, 'error' => $generic];
        }

        $stmt = db()->prepare('SELECT id, password, type FROM accounts WHERE email = ? ORDER BY id LIMIT 1');
        $stmt->execute([$email]);
        $row = $stmt->fetch();

        if (!$row || !hash_equals(strtolower((string)$row['password']), sha1($password))) {
            rl_hit('login', $ip);
            return ['ok' => false, 'error' => $generic];
        }

        rl_clear('login', $ip);
        session_regenerate_id(true);
        $_SESSION = [
            'account_id' => (int)$row['id'],
            'pwfp'       => hash('sha256', (string)$row['password']),
            'last'       => time(),
            'csrf'       => bin2hex(random_bytes(32)),
        ];

        return ['ok' => true, 'error' => null];
    }
}

if (!function_exists('logout_account')) {
    function logout_account(bool $destroy = true): void
    {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $p = session_get_cookie_params();
            setcookie(session_name(), '', [
                'expires'  => time() - 42000,
                'path'     => $p['path'],
                'domain'   => $p['domain'],
                'httponly' => $p['httponly'],
                'samesite' => $p['samesite'] ?? 'Lax',
                'secure'   => $p['secure'],
            ]);
        }
        if ($destroy && session_status() === PHP_SESSION_ACTIVE) {
            session_destroy();
        }
    }
}

if (!function_exists('require_login')) {
    function require_login(): void
    {
        if (current_account() === null) {
            header('Location: minha-conta.php');
            exit;
        }
    }
}
