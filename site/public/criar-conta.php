<?php
declare(strict_types=1);

require __DIR__ . '/../app/bootstrap.php';

$samples = (array)config('samples', []);

$acc = null;
try {
    $acc = current_account();
} catch (Throwable $e) {
    app_log('ERROR', 'auth ler falhou', ['class' => get_class($e)]);
}

if ($acc !== null) {
    render_header('Criar Conta', 'criar-conta.php');
    ?>
<section class="pergaminho">
<h2 class="barra-titulo">Criar Conta</h2>
<p>Você já está logado como <strong><?= e($acc['email']) ?></strong>.</p>
<p>Crie personagens adicionais na <a class="btn-link" href="minha-conta.php">Minha Conta</a>.</p>
</section>
<?php
    render_footer();
    exit;
}

$errors = [];
$old = ['email' => '', 'name' => '', 'vocation' => '', 'sex' => ''];

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $emailRaw = post_str('email');
    $password = post_str('password');
    $confirm  = post_str('confirm');
    $nameRaw  = post_str('name');
    $vocRaw   = post_str('vocation');
    $sexRaw   = post_str('sex');

    $old = [
        'email'    => trim($emailRaw),
        'name'     => trim($nameRaw),
        'vocation' => $vocRaw,
        'sex'      => $sexRaw,
    ];

    $ip = current_ip();
    if (rl_exceeded('register', $ip)) {
        $errors['form'] = 'Limite de cadastros por hora atingido. Tente mais tarde.';
    } else {
        $emailNorm = null;
        $m = validate_email($emailRaw, $emailNorm);
        if ($m !== null) {
            $errors['email'] = $m;
        }
        $m = validate_password($password, $confirm);
        if ($m !== null) {
            $errors['password'] = $m;
        }
        $name = normalize_char_name($nameRaw);
        $m = validate_char_name($name);
        if ($m !== null) {
            $errors['name'] = $m;
        }
        if (!ctype_digit($vocRaw) || !isset($samples[(int)$vocRaw])) {
            $errors['vocation'] = 'Escolha uma vocação válida.';
        }
        if ($sexRaw !== '0' && $sexRaw !== '1') {
            $errors['sex'] = 'Escolha o sexo do personagem.';
        }

        if ($errors === []) {
            $res = create_account_with_character((string)$emailNorm, $password, $name, (int)$vocRaw, (int)$sexRaw);
            if ($res['ok']) {
                rl_hit('register', $ip);
                login_account((string)$emailNorm, $password);
                flash('Conta criada! Bem-vindo ao ' . (string)config('server_name', 'TiozaoOT') . '.');
                header('Location: minha-conta.php', true, 303);
                exit;
            }
            if (!empty($res['field'])) {
                $errors[$res['field']] = (string)$res['error'];
            } else {
                $errors['form'] = (string)$res['error'];
            }
        }
    }
}

render_header('Criar Conta', 'criar-conta.php');
?>
<section class="pergaminho">
<h2 class="barra-titulo">Criar Conta</h2>

<?php if (isset($errors['form'])): ?>
<div class="erros" role="alert"><?= e($errors['form']) ?></div>
<?php endif; ?>

<form action="criar-conta.php" method="post" class="form-largo">
<?= csrf_field() ?>

<div class="campo">
<label for="email">Email</label>
<input type="text" id="email" name="email" inputmode="email" autocomplete="email" maxlength="255" required value="<?= e($old['email']) ?>">
<?php if (isset($errors['email'])): ?><p class="erro-campo"><?= e($errors['email']) ?></p><?php endif; ?>
</div>

<div class="campo">
<label for="password">Senha (mínimo 8 caracteres)</label>
<input type="password" id="password" name="password" autocomplete="new-password" maxlength="64" required>
<?php if (isset($errors['password'])): ?><p class="erro-campo"><?= e($errors['password']) ?></p><?php endif; ?>
</div>

<div class="campo">
<label for="confirm">Confirme a senha</label>
<input type="password" id="confirm" name="confirm" autocomplete="new-password" maxlength="64" required>
</div>

<div class="campo">
<label for="name">Nome do primeiro personagem</label>
<input type="text" id="name" name="name" maxlength="20" required value="<?= e($old['name']) ?>">
<?php if (isset($errors['name'])): ?><p class="erro-campo"><?= e($errors['name']) ?></p><?php endif; ?>
</div>

<div class="campo">
<label for="vocation">Vocação</label>
<select id="vocation" name="vocation" required>
<option value="">Escolha…</option>
<?php foreach ($samples as $vid => $sname): ?>
<option value="<?= (int)$vid ?>"<?= (string)$old['vocation'] === (string)$vid ? ' selected' : '' ?>><?= e(vocation_name((int)$vid)) ?></option>
<?php endforeach; ?>
</select>
<?php if (isset($errors['vocation'])): ?><p class="erro-campo"><?= e($errors['vocation']) ?></p><?php endif; ?>
</div>

<div class="campo">
<label for="sex">Sexo</label>
<select id="sex" name="sex" required>
<option value="">Escolha…</option>
<option value="0"<?= $old['sex'] === '0' ? ' selected' : '' ?>>Feminino</option>
<option value="1"<?= $old['sex'] === '1' ? ' selected' : '' ?>>Masculino</option>
</select>
<?php if (isset($errors['sex'])): ?><p class="erro-campo"><?= e($errors['sex']) ?></p><?php endif; ?>
</div>

<button type="submit" class="btn-verde btn-grande">Criar conta</button>
</form>
</section>
<?php
render_footer();
