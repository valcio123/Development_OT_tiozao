<?php
declare(strict_types=1);

// Testes unitários (sem banco, sem sessão). Uso: php tests/run.php

$app = dirname(__DIR__) . '/app';
require_once $app . '/log.php';
require_once $app . '/lua_config.php';
require_once $app . '/security.php';
require_once $app . '/validation.php';
require_once $app . '/vocations.php';
require_once $app . '/ratelimit.php';

$passed = 0;
$failed = 0;

function ok(bool $cond, string $label): void
{
    global $passed, $failed;
    if ($cond) {
        $passed++;
        fwrite(STDOUT, "  ok  - {$label}\n");
    } else {
        $failed++;
        fwrite(STDOUT, "FAIL  - {$label}\n");
    }
}

function section(string $name): void
{
    fwrite(STDOUT, "\n# {$name}\n");
}

// --- parse_lua_db_config ----------------------------------------------------
section('parse_lua_db_config');

$tmp = tempnam(sys_get_temp_dir(), 'lua');
file_put_contents($tmp, implode("\n", [
    '-- Config',
    'mysqlHost = "localhost"',
    "mysqlUser = 'root'",
    'mysqlPass = ""',
    'mysqlDatabase = "canary"',
    'mysqlDatabaseBackup = "backup"',
    '-- mysqlPort = 3307',
    '',
]));
$c = parse_lua_db_config($tmp);
ok($c['host'] === 'localhost', 'host com aspas duplas');
ok($c['user'] === 'root', "user com aspas simples");
ok($c['password'] === '', 'senha vazia preservada');
ok($c['database'] === 'canary', 'database (ignora a chave Backup)');
ok($c['port'] === 3306, 'port default 3306 quando comentado');

file_put_contents($tmp, "mysqlHost=\"db\"\nmysqlUser=\"u\"\nmysqlPort=3307\nmysqlDatabase=\"c\"\n");
$c = parse_lua_db_config($tmp);
ok($c['port'] === 3307, 'port numérico sem aspas');
ok($c['host'] === 'db', 'host sem espaços ao redor do =');
unlink($tmp);

// --- validate_email ---------------------------------------------------------
section('validate_email');

$n = null;
ok(validate_email(' A@B.com ', $n) === null && $n === 'a@b.com', 'normaliza maiúsculas e trim');
ok(validate_email('sem-arroba', $n) !== null, 'rejeita sem @');
ok(validate_email('a@b', $n) !== null, 'rejeita domínio sem ponto');
ok(validate_email('ok@dominio.com', $n) === null, 'aceita email válido');

// --- validate_password ------------------------------------------------------
section('validate_password');

ok(validate_password('1234567', '1234567') !== null, 'rejeita 7 caracteres');
ok(validate_password('12345678', '12345678') === null, 'aceita 8 caracteres');
ok(validate_password('12345678', '12345679') !== null, 'rejeita confirmação diferente');
ok(validate_password(str_repeat('a', 64), str_repeat('a', 64)) === null, 'aceita 64 caracteres');
ok(validate_password(str_repeat('a', 65), str_repeat('a', 65)) !== null, 'rejeita 65 caracteres');
ok(validate_password('  senha8  ', '  senha8  ') === null, 'não faz trim (espaços contam)');

// --- nomes de personagem ----------------------------------------------------
section('nome de personagem');

ok(normalize_char_name('  joao da silva ') === 'Joao Da Silva', 'normaliza capitalização');
ok(validate_char_name('Ab') !== null, 'rejeita 2 caracteres');
ok(validate_char_name('Abc') === null, 'aceita 3 caracteres');
ok(validate_char_name(str_repeat('A', 20)) === null, 'aceita 20 caracteres');
ok(validate_char_name(str_repeat('A', 21)) !== null, 'rejeita 21 caracteres');
ok(validate_char_name('Joao123') !== null, 'rejeita dígitos');
ok(validate_char_name('Joao  Silva') !== null, 'rejeita espaços duplos');
ok(validate_char_name('Gm Joao') !== null, 'rejeita palavra reservada gm');
ok(validate_char_name('Sample') !== null, 'rejeita sample');
ok(validate_char_name('Gmail Rei') === null, 'aceita quem contém "gm" como parte');

// --- skills -----------------------------------------------------------------
section('skill_columns');

ok(skill_columns('sword')[0] === 'skill_sword', 'sword mapeia para skill_sword');
ok(skill_columns('invalido')[0] === 'level', 'chave inválida cai em level');
ok(skill_columns(null)[0] === 'level', 'null cai em level');
ok(skill_columns('distance')[0] === 'skill_dist', 'distance mapeia para skill_dist');

// --- rate limit (núcleo) ----------------------------------------------------
section('rate limit (núcleo)');

$dir = sys_get_temp_dir() . '/tiozaoo_rl_' . bin2hex(random_bytes(4));
mkdir($dir, 0700, true);
$ip = '1.2.3.4';

ok(rl_exceeded_at($dir, 'login', $ip, 2, 100, 1000) === false, 'inicialmente não excedido');
rl_hit_at($dir, 'login', $ip, 100, 1000);
rl_hit_at($dir, 'login', $ip, 100, 1000);
ok(rl_exceeded_at($dir, 'login', $ip, 2, 100, 1000) === true, 'excedido após atingir o máximo');
ok(rl_retry_after_at($dir, 'login', $ip, 2, 100, 1000) === 100, 'retry-after correto');
rl_clear_at($dir, 'login', $ip);
ok(rl_exceeded_at($dir, 'login', $ip, 2, 100, 1000) === false, 'clear zera o bucket');

rl_hit_at($dir, 'login', $ip, 100, 500);
ok(rl_exceeded_at($dir, 'login', $ip, 1, 100, 1000) === false, 'timestamps antigos são podados');
rl_hit_at($dir, 'login', $ip, 100, 1000);
ok(rl_exceeded_at($dir, 'login', $ip, 1, 100, 1000) === true, 'conta só os dentro da janela');

array_map('unlink', glob($dir . '/*') ?: []);
@rmdir($dir);

// --- escape -----------------------------------------------------------------
section('escape HTML');

ok(e('<b>"x"&\'y\'</b>') === '&lt;b&gt;&quot;x&quot;&amp;&#039;y&#039;&lt;/b&gt;', 'escapa caracteres perigosos');

fwrite(STDOUT, "\n==== {$passed} ok, {$failed} falha(s) ====\n");
exit($failed === 0 ? 0 : 1);
