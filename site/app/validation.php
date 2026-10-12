<?php
// Validação de entradas. Devolvem null quando ok, ou a mensagem de erro em pt-BR.

if (!function_exists('validate_email')) {
    function validate_email(string $raw, ?string &$normalized): ?string
    {
        $normalized = mb_strtolower(trim($raw), 'UTF-8');

        if ($normalized === '' || mb_strlen($normalized, 'UTF-8') > 255) {
            return 'Informe um email válido.';
        }
        if (filter_var($normalized, FILTER_VALIDATE_EMAIL) === false) {
            return 'Informe um email válido.';
        }
        return null;
    }
}

if (!function_exists('validate_password')) {
    // Senha NUNCA passa por trim. Aplica-se à criação e à troca de senha.
    function validate_password(string $password, string $confirm): ?string
    {
        $len = mb_strlen($password, 'UTF-8');
        if ($len < 8 || $len > 64) {
            return 'A senha precisa ter de 8 a 64 caracteres.';
        }
        if ($password !== $confirm) {
            return 'As senhas não conferem.';
        }
        return null;
    }
}

if (!function_exists('normalize_char_name')) {
    function normalize_char_name(string $raw): string
    {
        return ucwords(strtolower(trim($raw)));
    }
}

if (!function_exists('validate_char_name')) {
    // Valida formato e reservados (não checa unicidade; isso é no repositório).
    function validate_char_name(string $normalized): ?string
    {
        $len = mb_strlen($normalized, 'UTF-8');
        if ($len < 3 || $len > 20) {
            return 'O nome deve ter de 3 a 20 letras, com espaços simples.';
        }
        if (!preg_match('/^[A-Za-z]+( [A-Za-z]+)*$/', $normalized)) {
            return 'O nome deve ter de 3 a 20 letras, com espaços simples.';
        }

        $reserved = ['god', 'gm', 'cm', 'sample'];
        foreach (preg_split('/ +/', strtolower($normalized)) ?: [] as $word) {
            if (in_array($word, $reserved, true)) {
                return 'Este nome é reservado.';
            }
        }
        return null;
    }
}
