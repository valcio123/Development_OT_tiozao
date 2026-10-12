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

$loginError = null;
$errors = [];       // erros de create_char / change_password / post_news
$staffDenied = false;

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    $action = post_str('action');

    if ($action === 'login') {
        $r = login_account(post_str('email'), post_str('password'));
        if ($r['ok']) {
            flash('Login efetuado. Bem-vindo!');
            header('Location: minha-conta.php', true, 303);
            exit;
        }
        $loginError = $r['error'];
    } elseif ($action === 'logout') {
        logout_account();
        header('Location: minha-conta.php', true, 303);
        exit;
    } else {
        // Demais ações exigem sessão.
        if ($acc === null) {
            header('Location: minha-conta.php');
            exit;
        }

        if ($action === 'create_char') {
            $nameRaw = post_str('name');
            $vocRaw  = post_str('vocation');
            $sexRaw  = post_str('sex');
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
                $res = create_character($acc['id'], $name, (int)$vocRaw, (int)$sexRaw);
                if ($res['ok']) {
                    flash('Personagem ' . $name . ' criado com sucesso.');
                    header('Location: minha-conta.php', true, 303);
                    exit;
                }
                if (!empty($res['field'])) {
                    $errors[$res['field']] = (string)$res['error'];
                } else {
                    $errors['form'] = (string)$res['error'];
                }
            }
        } elseif ($action === 'change_password') {
            $current = post_str('current');
            $new     = post_str('new');
            $confirm = post_str('confirm');
            $ip = current_ip();
            if (rl_exceeded('login', $ip)) {
                $mins = max(1, (int)ceil(rl_retry_after('login', $ip) / 60));
                $errors['password'] = "Muitas tentativas. Tente novamente em {$mins} minutos.";
            } elseif (!hash_equals(strtolower($acc['password']), sha1($current))) {
                rl_hit('login', $ip);
                $errors['password'] = 'Senha atual incorreta.';
            } else {
                $m = validate_password($new, $confirm);
                if ($m !== null) {
                    $errors['password'] = $m;
                } else {
                    change_password($acc['id'], $new);
                    rl_clear('login', $ip);
                    session_regenerate_id(true);
                    $_SESSION['pwfp'] = hash('sha256', sha1($new));
                    flash('Senha alterada com sucesso.');
                    header('Location: minha-conta.php', true, 303);
                    exit;
                }
            }
        } elseif ($action === 'post_news' || $action === 'delete_news') {
            if ($acc['type'] < 5) {
                http_response_code(403);
                app_log('WARNING', 'notícia sem permissão', ['account_id' => $acc['id']]);
                render_error('Acesso negado.', 'Acesso negado');
                exit;
            }
            if ($action === 'post_news') {
                $title = trim(post_str('title'));
                $body  = trim(post_str('body'));
                $titleLen = mb_strlen($title, 'UTF-8');
                $bodyLen  = mb_strlen($body, 'UTF-8');
                if ($titleLen < 3 || $titleLen > 120) {
                    $errors['news_title'] = 'O título deve ter de 3 a 120 caracteres.';
                }
                if ($bodyLen < 1 || $bodyLen > 5000) {
                    $errors['news_body'] = 'O texto deve ter até 5000 caracteres.';
                }
                if ($errors === []) {
                    news_create($title, $body, (string)$acc['email']);
                    flash('Notícia publicada.');
                    header('Location: minha-conta.php', true, 303);
                    exit;
                }
            } else {
                $id = post_str('id');
                if (!ctype_digit($id) || (int)$id <= 0) {
                    flash('Notícia não encontrada.');
                    header('Location: minha-conta.php', true, 303);
                    exit;
                }
                news_delete((int)$id);
                flash('Notícia apagada.');
                header('Location: minha-conta.php', true, 303);
                exit;
            }
        } else {
            http_response_code(400);
            render_error('Requisição inválida.', 'Erro');
            exit;
        }
    }
}

// Leituras de banco da página, antes de render_header.
$chars = [];
$myNews = [];
$isStaff = false;
if ($acc !== null) {
    try {
        $chars = characters_of($acc['id']);
        $isStaff = $acc['type'] >= 5;
        if ($isStaff) {
            $myNews = news_list(10);
        }
    } catch (PDOException $e) {
        app_log('ERROR', 'minha-conta DB falhou', ['code' => $e->getCode()]);
        http_response_code(503);
        render_error('Site temporariamente indisponível.', 'Indisponível');
        exit;
    }
}

render_header('Minha Conta', 'minha-conta.php');

if ($acc === null) {
    ?>
<section class="pergaminho">
<h2 class="barra-titulo">Entrar</h2>
<?php if ($loginError !== null): ?>
<div class="erros" role="alert"><?= e($loginError) ?></div>
<?php endif; ?>
<form action="minha-conta.php" method="post" class="form-largo">
<?= csrf_field() ?>
<input type="hidden" name="action" value="login">
<div class="campo">
<label for="login-email">Email</label>
<input type="text" id="login-email" name="email" inputmode="email" autocomplete="username" maxlength="255" required>
</div>
<div class="campo">
<label for="login-password">Senha</label>
<input type="password" id="login-password" name="password" autocomplete="current-password" maxlength="256" required>
</div>
<button type="submit" class="btn-ouro btn-grande">Entrar</button>
</form>
<p class="dica">Não tem conta? <a class="btn-link" href="criar-conta.php">Criar Conta</a></p>
</section>
<?php
    render_footer();
    exit;
}
?>
<section class="pergaminho">
<h2 class="barra-titulo">Minha Conta</h2>
<p>Logado como <strong><?= e($acc['email']) ?></strong>.</p>

<h3>Meus personagens</h3>
<?php if ($chars === []): ?>
<p class="vazio">Você ainda não tem personagens.</p>
<?php else: ?>
<div class="tabela-wrap">
<table>
<thead><tr><th>Nome</th><th>Vocação</th><th>Level</th><th>Online</th></tr></thead>
<tbody>
<?php foreach ($chars as $c): ?>
<tr>
<td><?= e($c['name']) ?></td>
<td><?= e(vocation_name((int)$c['vocation'])) ?></td>
<td><?= (int)$c['level'] ?></td>
<td><?= ((int)$c['online'] === 1) ? 'Sim' : 'Não' ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
</div>
<?php endif; ?>

<h3>Criar personagem</h3>
<?php if (isset($errors['form'])): ?><div class="erros" role="alert"><?= e($errors['form']) ?></div><?php endif; ?>
<form action="minha-conta.php" method="post" class="form-largo">
<?= csrf_field() ?>
<input type="hidden" name="action" value="create_char">
<div class="campo">
<label for="cname">Nome do personagem</label>
<input type="text" id="cname" name="name" maxlength="20" required>
<?php if (isset($errors['name'])): ?><p class="erro-campo"><?= e($errors['name']) ?></p><?php endif; ?>
</div>
<div class="campo">
<label for="cvocation">Vocação</label>
<select id="cvocation" name="vocation" required>
<option value="">Escolha…</option>
<?php foreach ($samples as $vid => $sname): ?>
<option value="<?= (int)$vid ?>"><?= e(vocation_name((int)$vid)) ?></option>
<?php endforeach; ?>
</select>
<?php if (isset($errors['vocation'])): ?><p class="erro-campo"><?= e($errors['vocation']) ?></p><?php endif; ?>
</div>
<div class="campo">
<label for="csex">Sexo</label>
<select id="csex" name="sex" required>
<option value="">Escolha…</option>
<option value="0">Feminino</option>
<option value="1">Masculino</option>
</select>
<?php if (isset($errors['sex'])): ?><p class="erro-campo"><?= e($errors['sex']) ?></p><?php endif; ?>
</div>
<button type="submit" class="btn-verde">Criar personagem</button>
</form>

<h3>Trocar senha</h3>
<?php if (isset($errors['password'])): ?><div class="erros" role="alert"><?= e($errors['password']) ?></div><?php endif; ?>
<form action="minha-conta.php" method="post" class="form-largo">
<?= csrf_field() ?>
<input type="hidden" name="action" value="change_password">
<div class="campo">
<label for="cur">Senha atual</label>
<input type="password" id="cur" name="current" autocomplete="current-password" maxlength="256" required>
</div>
<div class="campo">
<label for="new">Nova senha (mínimo 8 caracteres)</label>
<input type="password" id="new" name="new" autocomplete="new-password" maxlength="64" required>
</div>
<div class="campo">
<label for="newc">Confirme a nova senha</label>
<input type="password" id="newc" name="confirm" autocomplete="new-password" maxlength="64" required>
</div>
<button type="submit" class="btn-ouro">Alterar senha</button>
</form>

<?php if ($isStaff): ?>
<h3>Publicar notícia</h3>
<?php if (isset($errors['news_title'])): ?><p class="erro-campo"><?= e($errors['news_title']) ?></p><?php endif; ?>
<?php if (isset($errors['news_body'])): ?><p class="erro-campo"><?= e($errors['news_body']) ?></p><?php endif; ?>
<form action="minha-conta.php" method="post" class="form-largo">
<?= csrf_field() ?>
<input type="hidden" name="action" value="post_news">
<div class="campo">
<label for="ntitle">Título</label>
<input type="text" id="ntitle" name="title" maxlength="120" required value="<?= e(trim(post_str('title'))) ?>">
</div>
<div class="campo">
<label for="nbody">Texto</label>
<textarea id="nbody" name="body" rows="6" maxlength="5000" required><?= e(trim(post_str('body'))) ?></textarea>
</div>
<button type="submit" class="btn-verde">Publicar</button>
</form>

<h3>Últimas notícias</h3>
<?php if ($myNews === []): ?>
<p class="vazio">Nenhuma notícia.</p>
<?php else: ?>
<ul class="lista-noticias-staff">
<?php foreach ($myNews as $n): ?>
<li>
<span><?= e($n['title']) ?></span>
<form action="minha-conta.php" method="post" class="form-inline">
<?= csrf_field() ?>
<input type="hidden" name="action" value="delete_news">
<input type="hidden" name="id" value="<?= (int)$n['id'] ?>">
<button type="submit" class="btn-apagar">Apagar</button>
</form>
</li>
<?php endforeach; ?>
</ul>
<?php endif; ?>
<?php endif; ?>

</section>
<?php
render_footer();
