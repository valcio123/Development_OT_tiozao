<?php
declare(strict_types=1);

require __DIR__ . '/../app/bootstrap.php';

$url = (string)config('download_url', '');

render_header('Download', 'download.php');
?>
<section class="pergaminho">
<h2 class="barra-titulo">Download</h2>

<?php if ($url === ''): ?>
<p class="link-em-breve">Link em breve</p>
<?php else: ?>
<p><a class="btn-ouro btn-grande" href="<?= e($url) ?>" rel="noopener noreferrer">Baixar Client</a></p>
<?php endif; ?>

<h2 class="barra-titulo">Como jogar</h2>
<ol class="como-jogar">
<li>Baixe o client pelo botão acima.</li>
<li>Extraia o arquivo .zip numa pasta (ex.: Área de Trabalho).</li>
<li>Abra o <code>otclient.exe</code>.</li>
<li>Entre com o email e a senha da sua conta (crie em <a class="btn-link" href="criar-conta.php">Criar Conta</a>).</li>
</ol>
</section>
<?php
render_footer();
