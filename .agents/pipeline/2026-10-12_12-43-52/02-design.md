# Design técnico: site próprio "Clássico Medieval" do TiozaoOT

Requisitos: `01-requirements.md` (deste run). Brief autoritativo: `E:\Amigos_OT\canary\.agents\tasks\site-proprio-brief.md`.

## Visão geral

O site é um PHP 8.2 puro (o PHP do XAMPP, `C:\xampp\php\php.exe`, com PDO, pdo_mysql, mbstring e openssl confirmados). Não usa framework, Composer, JavaScript nem CDN. O código fica em `E:\Amigos_OT\site`, e só `site\public` é exposto via HTTP. Cada página é um arquivo PHP próprio em `public\`. Todos esses arquivos fazem `require` de um bootstrap em `site\app\`, que cuida da config, do log, da sessão, do CSRF e dos headers de segurança, e expõe helpers de banco, validação e layout. O banco é o `canary` de produção, acessado por PDO com prepared statements.

Para integrar com o Apache, um `<VirtualHost *:7180>` é acrescentado ao `httpd-vhosts.conf` (incluído pelo httpd.conf, hoje sem blocos ativos). O DocumentRoot desse vhost é `site\public`, e um `Alias /login.php` aponta para o `C:\xampp\htdocs\login.php` original. As portas 80 e 8080 não casam com nenhum vhost e continuam no servidor principal (MyAAC). O Apache só aplica a mudança depois de reiniciar, e quem reinicia é o usuário, pelo painel do XAMPP. Até lá, o site é testado com `php -S`.

### Fatos verificados no ambiente (esta exploração)
- `httpd.conf`: `Listen 80/8080/7180`, `DocumentRoot "C:/xampp/htdocs"`, `<Directory />` com `Require all denied`, `<Directory "C:/xampp/htdocs">` com `Require all granted`, mod_alias e mod_rewrite carregados, `Include conf/extra/httpd-vhosts.conf` (só comentários). O handler PHP é global (`httpd-xampp.conf`).
- `login.php` faz `require_once 'common.php'`, e o `common.php` usa `BASE = __DIR__ . '/'`. Os includes, portanto, resolvem pelo diretório do próprio arquivo e funcionam via Alias. O IP do mundo vem de `REMOTE_ADDR`, e o vhost não muda esse valor.
- O OTClient local usa `http://127.0.0.1/login.php`, na porta 80. Na 7180, os amigos só precisam de `/login.php`.
- config.lua:
  - credenciais do banco (host, user, database, port) lidas do `config.lua` local, que **não é versionado**;
  - o parser tem de aceitar senha vazia;
  - `serverName="TiozaoOT"`, `statusProtocolPort=7171`, `passwordType="sha1"`, `authType="password"`.
- O Canary procura a conta por `email` (`account_repository_db.cpp: loadByEmailOrName`), e a senha é SHA1 hexadecimal. As contas existentes têm hash de 40 caracteres hex minúsculos.
- `accounts`:
  - InnoDB, utf8_general_ci;
  - colunas NOT NULL sem default: `name` (varchar 32, UNIQUE) e `password`;
  - `email` tem índice não-único;
  - as demais têm default (`key`='', `created`=0, `rlname`='', `type`=1, `creation`=0…).
- `players`:
  - InnoDB, utf8_general_ci;
  - `name` é UNIQUE (case-insensitive pela collation);
  - `conditions` é mediumblob NOT NULL sem default;
  - as demais têm default.
- Samples em `players`: ids 1-6, conta 1, group 1, town 8, sex 1, looktype 129. Nomes: Rook, Sorcerer, Druid, Paladin, Knight e Monk Sample. Cada um tem 1 linha em `player_items` (pid 11, sid 101, itemtype 23396).
- Vocações (`vocations.xml`): 0 None, 1 Sorcerer, 2 Druid, 3 Paladin, 4 Knight, 5 Master Sorcerer, 6 Elder Druid, 7 Royal Paladin, 8 Elite Knight, 9 Monk e 10 Exalted Monk.
- `server_config` tem `players_record`. `players_online` tem só `player_id`.
- Não existe tabela `site_news`. `E:\Amigos_OT\site` não existe. `E:\Amigos_OT\backups\` existe e usa o padrão de nome `<arquivo>.<yyyyMMdd_HHmmss>` e `canary_backup_<ts>.sql`.
- O Edge está em `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`.

## Stack (travada)
- PHP 8.2.12 do XAMPP, sem extensões além das já carregadas: PDO, pdo_mysql, mbstring, session e openssl.
- MariaDB 10.4 (`canary`), com PDO DSN `mysql:host=…;port=…;dbname=…;charset=utf8mb4`, `ERRMODE_EXCEPTION`, `EMULATE_PREPARES=false`, `FETCH_ASSOC` e `ATTR_TIMEOUT=3`.
- HTML5 com CSS próprio, sem JavaScript, sem webfonts e sem CDN. Fontes: `"Palatino Linotype", "Book Antiqua", Palatino, Georgia, serif`.
- Apache 2.4 do XAMPP, só com a mudança em `httpd-vhosts.conf`.
- Testes: um runner PHP sem framework (`site\tests\run.php`) e um smoke test em PowerShell (`site\tests\smoke.ps1`). Não há PHPUnit disponível, e o brief proíbe dependências.

## Estrutura de arquivos

```
E:\Amigos_OT\site\
  config\config.php          -- array de configuração (nome, link do Drive, limites…)
  app\bootstrap.php          -- carrega tudo, ini/erros, sessão, headers, CSRF global
  app\log.php                -- app_log($level, $msg, $ctx)
  app\lua_config.php         -- parse_lua_db_config(string $path): array
  app\db.php                 -- db(): PDO (lazy, singleton)
  app\security.php           -- e(), csrf_token(), csrf_field(), csrf_check(), post_str()
  app\auth.php               -- current_account(), login_account(), logout_account(), require_login()
  app\ratelimit.php          -- rl_exceeded(), rl_hit(), rl_clear(), rl_retry_after()
  app\validation.php         -- validate_email(), validate_password(), normalize_char_name(), validate_char_name()
  app\vocations.php          -- VOCATION_NAMES, SKILL_COLUMNS
  app\repo_accounts.php      -- create_account_with_character(), find_account_by_email(), change_password()
  app\repo_players.php       -- create_character(), characters_of(), ranking(), top_level(), online_players()
  app\repo_news.php          -- news_list(), news_create(), news_delete()
  app\status.php             -- server_status(): array (cache de 30 s)
  app\layout.php             -- render_header($title, $active), render_footer(), flash()
  bin\install.php            -- CLI: CREATE TABLE IF NOT EXISTS site_news + seed
  bin\delete-test-account.php-- CLI: apaga conta de teste (só @tiozaoot.test)
  tests\run.php              -- testes unitários (asserts)
  tests\smoke.ps1            -- teste integrado HTTP com WebSession
  storage\logs\  storage\sessions\  storage\ratelimit\  storage\cache\
  public\index.php            -- Início/Notícias
  public\criar-conta.php
  public\minha-conta.php
  public\ranking.php
  public\online.php
  public\download.php
  public\assets\css\style.css
  public\assets\img\castelo.svg  -- silhueta do castelo (fundo decorativo via CSS)
```

O bootstrap cria os diretórios `storage\*` se faltarem (`mkdir(..., 0700, true)`). Nada em `public\` contém segredo ou lógica além de "carregar o bootstrap, tratar a requisição e renderizar".

## Decisões principais

**Páginas em arquivos separados, com links relativos e sem rewrite.** Cada página é um `.php` em `public\`. Todos os links e assets são relativos e sem barra inicial (`ranking.php`, `assets/css/style.css`). O site, então, funciona igual na raiz da 7180, no `php -S` e num eventual fallback `/site/`, sem nenhuma mudança de código. Também é impossível vazar host fixo. Os redirects usam `Location:` relativo (`minha-conta.php`), permitido pela RFC 7231. Descartei um front controller com rewrite porque exige configuração no `php -S` e no Apache e não traz ganho aqui.

**Integração com o Apache: vhost na 7180 com Alias para login.php.** Antes, faço backup de `C:\xampp\apache\conf\extra\httpd-vhosts.conf` em `E:\Amigos_OT\backups\httpd-vhosts.conf.<yyyyMMdd_HHmmss>`. Depois, acrescento ao final:

```apache
# TiozaoOT - site próprio na porta 7180 (login.php continua sendo o do MyAAC)
<VirtualHost *:7180>
    ServerName tiozaoot-site
    DocumentRoot "E:/Amigos_OT/site/public"
    <Directory "E:/Amigos_OT/site/public">
        Options FollowSymLinks
        AllowOverride None
        Require all granted
        DirectoryIndex index.php
    </Directory>
    Alias /login.php "C:/xampp/htdocs/login.php"
    ErrorLog "logs/tiozaoot-site-error.log"
    CustomLog "logs/tiozaoot-site-access.log" common
</VirtualHost>
```

Escolhi editar o `httpd-vhosts.conf`, e não o `httpd.conf`, porque ele já é incluído e está vazio. Assim, o `httpd.conf` fica intacto e o rollback consiste em restaurar um único arquivo. Os pontos que fazem isso funcionar:
- `Options` sem `Indexes` impede a listagem de diretórios.
- Como os diretórios `config`, `app` e `storage` estão fora do DocumentRoot e o `<Directory />` nega tudo, eles não ficam acessíveis.
- O destino do Alias já tem `Require all granted` pelo bloco global de `C:/xampp/htdocs`.
- Os Alias globais do XAMPP (`/phpmyadmin`, `/licenses`, `/webalizer`) continuam com `Require local`, como hoje.

Efeito colateral positivo: o resto do MyAAC (`/admin`, `/install`…) deixa de ser exposto na internet pela 7180. Ele continua disponível em `http://127.0.0.1/`. A validação é feita com `C:\xampp\apache\bin\httpd.exe -t`, que precisa retornar "Syntax OK". Se o resultado for diferente, restauro o backup e uso o fallback abaixo.

Fallback (RF1.3), usado só se a raiz falhar depois do restart: troco o bloco por um `Alias /site "E:/Amigos_OT/site/public"` com o mesmo `<Directory>`, sem vhost, e documento a troca no relatório. Como os links são relativos, o código não muda.

**Credenciais do banco lidas do config.lua.** `parse_lua_db_config($path)` lê o arquivo linha a linha e casa `^\s*(mysqlHost|mysqlUser|mysqlPass|mysqlDatabase|mysqlPort)\s*=\s*(?:"([^"]*)"|(\d+))`.
- Aceita valor de senha vazio.
- Ignora linhas comentadas (`--`).
- Exige host, user e database. Sem port, usa 3306. Sem pass, usa string vazia.

O caminho vem de `config.php` (`canary_config_lua`). A senha nunca entra em log nem em mensagem de exceção: a função lança `RuntimeException('config.lua: chave X ausente')`, só com o nome da chave. Não dupliquei as credenciais num arquivo próprio para não ter duas fontes de verdade.

**Configuração (`config\config.php`).** O arquivo retorna:

```php
return [
  'server_name'       => 'TiozaoOT',
  'tagline'           => 'Uma nova aventura começa aqui',
  'client_version'    => '15.25',
  'download_url'      => '',            // link do Google Drive; vazio => "Link em breve"
  'canary_config_lua' => 'E:/Amigos_OT/canary/config.lua',
  'status_host'       => '127.0.0.1',
  'status_port'       => 7171,
  'status_timeout'    => 1.0,           // segundos (<= 1)
  'status_cache_ttl'  => 30,            // segundos
  'timezone'          => 'America/Sao_Paulo',
  'samples'           => [1 => 'Sorcerer Sample', 2 => 'Druid Sample', 3 => 'Paladin Sample',
                          4 => 'Knight Sample', 9 => 'Monk Sample'],
  'max_characters'    => 10,
  'login_limit'       => ['max' => 5, 'window' => 900],   // falhas por IP / 15 min
  'register_limit'    => ['max' => 3, 'window' => 3600],  // contas criadas por IP / 1 h
  'ranking_limit'     => 50,
  'session_idle'      => 7200,
];
```

Regras de validação da config, aplicadas no bootstrap:
- `download_url` só é usada se casar `^https://`. Qualquer outro valor é tratado como vazio, com log WARNING `download_url inválida`.
- `server_name` vazio vira "TiozaoOT".
- Se o config.php estiver ausente ou não retornar array, o erro é fatal: HTTP 500 com página genérica e log CRITICAL.

**Notícias numa tabela `site_news`, publicadas pelo site.** O `bin\install.php` (CLI, idempotente) executa:

```sql
CREATE TABLE IF NOT EXISTS site_news (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(120) NOT NULL,
  body TEXT NOT NULL,
  author VARCHAR(64) NOT NULL DEFAULT '',
  created_at INT UNSIGNED NOT NULL,
  KEY idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Se a tabela estiver vazia, o script insere o seed com título "Servidor aberto para os amigos!", um corpo curto em pt-BR, autor = `server_name` e `created_at=time()`. Para publicar, uma conta com `accounts.type >= 5`, conferido no banco a cada ação e não pelo cache da sessão, vê na Minha Conta a seção "Publicar notícia" (título e texto) e a lista das últimas 10 notícias, cada uma com o botão "Apagar" (POST + CSRF). O corpo é texto puro, renderizado como `nl2br(e($body))`, sem HTML do usuário. Escolhi banco em vez de arquivo para ter escrita concorrente segura e prepared statements uniformes. A tabela é aditiva e não toca em nada do Canary nem do MyAAC.

**Criação de conta e personagem, compatível com o Canary e o MyAAC.** Tudo acontece numa transação PDO, porque as tabelas são InnoDB:
1. `SELECT id FROM accounts WHERE email = ? FOR UPDATE`. Se existir, o erro vai para o campo email: "Este email já está cadastrado.". O `FOR UPDATE` no índice não-único faz gap lock em REPEATABLE READ e bloqueia cadastros concorrentes do mesmo email, já que não há UNIQUE no email.
2. `SELECT 1 FROM players WHERE name = ?`. Se existir, o erro vai para o campo nome: "Este nome já está em uso.".
3. Carrego o sample: `SELECT * FROM players WHERE name = ? LIMIT 1`, com o nome vindo de `config.samples[vocation]`. Se faltar, é erro de configuração: rollback, log ERROR `sample ausente: <nome>` e mensagem genérica.
4. `INSERT INTO accounts (name, password, email, \`key\`, created, creation, rlname, location, country, type, premdays, lastday) VALUES (?, ?, ?, '', ?, ?, '', '', '', 1, 0, 0)`.
   - `name` = `'w' . bin2hex(random_bytes(7))`, com 15 caracteres. É obrigatório e UNIQUE, mas não é usado no login por email.
   - `password` = `sha1($senha)`, que já retorna hex minúsculo.
   - `email` = email normalizado (trim + minúsculas).
   - `created` = `creation` = `time()`.
5. `INSERT INTO players (name, account_id, group_id, sex, vocation, level, experience, health, healthmax, mana, manamax, manaspent, maglevel, soul, cap, town_id, posx, posy, posz, conditions, looktype, lookhead, lookbody, looklegs, lookfeet, lookaddons, stamina, skill_fist, skill_club, skill_sword, skill_axe, skill_dist, skill_shielding, skill_fishing, balance, created) SELECT ?, ?, 1, ?, vocation, level, experience, health, healthmax, mana, manamax, manaspent, maglevel, soul, cap, town_id, 0, 0, 0, conditions, CASE WHEN ? = 0 THEN 136 ELSE looktype END, lookhead, lookbody, looklegs, lookfeet, lookaddons, stamina, skill_fist, skill_club, skill_sword, skill_axe, skill_dist, skill_shielding, skill_fishing, 0, ? FROM players WHERE id = ?`. Se o número de linhas afetadas não for 1, faço rollback e trato como erro interno. Detalhes:
   - O town vem do sample (8, Thais), como nos personagens existentes.
   - Com posição 0/0/0, o Canary leva o personagem ao templo da cidade.
   - O feminino usa looktype 136, igual ao MyAAC (`CreateCharacter.php`).
6. `INSERT INTO player_items (player_id, pid, sid, itemtype, count, attributes) SELECT ?, pid, sid, itemtype, count, attributes FROM player_items WHERE player_id = ?`, para paridade com o MyAAC, que copia os itens do sample.
7. Commit.

Um `PDOException` com SQLSTATE `23000` durante a transação significa corrida no nome (UNIQUE de players.name) ou, em teoria, colisão no accounts.name. Nesse caso: rollback, e a mensagem do campo nome é "Este nome já está em uso.". Qualquer outra exceção leva a rollback, log ERROR com a mensagem do PDO (sem dados de entrada) e erro genérico. Com sucesso, registro um hit em `register` no rate limit, log INFO `conta criada id=<id>`, login automático (`login_account`, que regenera o ID) e redirect 303 para `minha-conta.php` com o flash "Conta criada! Bem-vindo ao TiozaoOT.".

O personagem adicional (Minha Conta) usa `create_character($accountId, ...)`. São os passos 2, 3, 5 e 6 numa transação, mais uma contagem `SELECT COUNT(*) FROM players WHERE account_id = ? FOR UPDATE` antes. Se o resultado for `>= max_characters` (10), o erro é "Limite de 10 personagens por conta atingido.".

**Login e sessão.** `login_account()` é usada pelo login da coluna direita e pelo da Minha Conta: os dois postam em `minha-conta.php` com `action=login`. A ordem é:
1. Se `rl_exceeded('login', ip)`, a resposta é "Muitas tentativas de login. Tente novamente em N minutos." e a senha nem é verificada.
2. `SELECT id, password, type FROM accounts WHERE email = ?`. A collation ci casa como o Canary.
3. `hash_equals(strtolower($row['password']), sha1($senha))`.
4. Se falhar: `rl_hit('login', ip)` e mensagem genérica "Email ou senha incorretos." (sem revelar se o email existe).
5. Se der certo: `rl_clear('login', ip)`, `session_regenerate_id(true)`, `$_SESSION = ['account_id'=>id, 'pwfp'=>hash('sha256', $row['password']), 'last'=>time(), 'csrf'=>novo token]` e redirect 303 para `minha-conta.php`.

No login, o campo email é `type="text" inputmode="email" autocomplete="username"` e só passa por trim e limite de 255 caracteres, sem validação de formato. Assim, contas com email em formato incomum também entram. A senha aceita até 256 caracteres no login (limite contra abuso).

Em cada requisição, `current_account()` recarrega `id, email, type, password` pelo `account_id`. A sessão é invalidada se:
- a conta sumiu;
- `hash('sha256', password) !== pwfp` (a senha mudou em outro lugar);
- `time() - last > session_idle`.

Fora isso, `last` é atualizado.

Parâmetros da sessão, definidos no bootstrap antes do `session_start()`:
- `session_name('TIOZAOSID')`;
- `session_save_path(storage/sessions)`, isolado do MyAAC;
- `ini_set('session.use_strict_mode','1')`, `use_only_cookies=1` e `use_trans_sid=0`;
- `session_set_cookie_params(['lifetime'=>0,'path'=>'/','httponly'=>true,'samesite'=>'Lax','secure'=>false])`. O `secure=false` é necessário porque o site não tem TLS, e isso vai no relatório.

O logout é só por POST com CSRF: `$_SESSION=[]`, expira o cookie com os mesmos params, chama `session_destroy()` e redireciona para `minha-conta.php`.

**Troca de senha.** São três campos: atual, nova e confirmação. A senha atual errada conta como falha no bucket `login` (protege contra força bruta com sessão roubada) e respeita o bloqueio. A nova segue `validate_password`. Com sucesso: `UPDATE accounts SET password = ? WHERE id = ?`, `session_regenerate_id(true)`, atualização do `pwfp` e o flash "Senha alterada com sucesso.".

**CSRF centralizado no bootstrap.** O token é `bin2hex(random_bytes(32))` em `$_SESSION['csrf']`, criado sob demanda. Todo formulário POST inclui `csrf_field()`. O `bootstrap.php`, depois do `session_start()`, executa: se `REQUEST_METHOD === 'POST'` e `!hash_equals($_SESSION['csrf'] ?? '', (string)($_POST['_csrf'] ?? ''))`, responde HTTP 400 com a página "Sua sessão expirou. Recarregue a página e tente de novo." e faz `exit`, antes de qualquer lógica de página. Um `$_POST['_csrf']` que não seja string vira ''. A responsabilidade é do bootstrap: nenhuma página consegue esquecer a checagem, e o critério de aceite 4 ("nada é gravado") vira consequência estrutural, já que o exit vem antes do código de escrita.

**Rate limit em arquivos.** Cada bucket+IP corresponde a um arquivo `storage/ratelimit/<sha256(bucket.'|'.ip)>.json` com a lista de timestamps. As operações abrem com `fopen('c+')` e `flock(LOCK_EX)`, descartam timestamps mais velhos que a janela e então leem ou gravam:
- `rl_exceeded(bucket, ip)` retorna `count >= max`;
- `rl_hit` adiciona `time()`;
- `rl_clear` apaga o arquivo;
- `rl_retry_after` devolve os segundos até o timestamp mais antigo expirar.

O IP é só `$_SERVER['REMOTE_ADDR']`, sem confiar em `X-Forwarded-For`, porque não há proxy (A6). Se a pasta não for gravável, o comportamento é fail-open, com log ERROR `ratelimit indisponível`. Escolhi fail-open para não derrubar o login do site por erro de disco, e o risco fica registrado no log. Os buckets são `login` (5 falhas em 15 min) e `register` (3 contas criadas por IP em 1 h, contando só os sucessos e checando antes de validar). Os arquivos de IPs expirados não são varridos: são poucos e pequenos, e o volume é desprezível. Uso arquivos para não criar mais uma tabela no banco de produção e para isolar falhas.

**Status do servidor com cache de 30 s.** `server_status()` lê `storage/cache/status.json`. Se o cache tiver menos de `status_cache_ttl` segundos, devolve `online` do cache. Caso contrário, faz `@fsockopen(status_host, status_port, $errno, $errstr, status_timeout)` e fecha logo em seguida. O resultado é salvo de forma atômica (escrita em `.tmp` + `rename`). O cache evita uma conexão TCP no Canary a cada página vista. Além disso:
- `players` vem de `SELECT COUNT(*) FROM players_online`, sem cache, para bater com o AC 15;
- `record` vem de `SELECT value FROM server_config WHERE config = 'players_record'` (null se não houver);
- `version` vem de `client_version`.

O uptime fica de fora (A7): não há fonte confiável sem implementar o protocolo de status do Canary, que tem limite por IP. Se o banco falhar, a caixa mostra o servidor e "—" nos números, com log ERROR.

**Ranking.** `SKILL_COLUMNS` é a whitelist que mapeia a chave do GET para as colunas de ordenação:
- `level` → `level`, `experience`;
- `magic` → `maglevel`, `manaspent`;
- `sword` → `skill_sword`, `skill_sword_tries`;
- `club` → `skill_club`, `skill_club_tries`;
- `axe` → `skill_axe`, `skill_axe_tries`;
- `distance` → `skill_dist`, `skill_dist_tries`;
- `shielding` → `skill_shielding`, `skill_shielding_tries`;
- `fishing` → `skill_fishing`, `skill_fishing_tries`.

Uma chave ausente, desconhecida ou que não seja string cai em `level`. Só valores dessa whitelist entram no SQL como identificadores. A query é `SELECT name, vocation, level, <col> AS value FROM players WHERE group_id < 4 AND deletion = 0 AND name NOT LIKE '% Sample' ORDER BY <col> DESC, <tries> DESC, name ASC LIMIT ?`, com o limite 50 como inteiro ligado. É um top 50 sem paginação, que basta para o grupo de amigos e mantém o código simples. O `top_level(5)` usa a mesma função com `skill=level` e limite 5, o que garante os mesmos critérios de exclusão (RF7.4). Os nomes Sample vêm de `'% Sample'`, e o cadastro proíbe a palavra "Sample", então não há falso positivo.

**Online.** A query é `SELECT p.name, p.vocation, p.level FROM players_online o JOIN players p ON p.id = o.player_id ORDER BY p.level DESC, p.name`. Mostra todos, inclusive staff, para o total bater com a caixa de status. Lista vazia mostra "Nenhum jogador online no momento.".

**Nomes de vocação.** `VOCATION_NAMES` em `app/vocations.php` é fixo, conforme o `vocations.xml`: 0 "Sem vocação", 1-10 com os nomes do XML. Um id desconhecido vira "Desconhecida". Não leio o XML em runtime para evitar I/O e parse a cada página.

**Layout e visual.** `render_header($title, $active)` emite:
- `<!doctype html><html lang="pt-BR">`, meta charset e viewport, `<title>`, o link `assets/css/style.css` e o skip link "Pular para o conteúdo";
- o `<header>` com `<h1 class="logo">` (texto `server_name`) e `<p class="tagline"><em>…</em></p>`;
- `<div class="layout">` com `<nav aria-label="Menu principal" class="col-left">` (lista de links, `aria-current="page"` no ativo, e a caixa de status `<section aria-labelledby>`) e a abertura de `<main id="conteudo" class="col-center">`.

`render_footer()` fecha o `main` e emite `<aside class="col-right">`. O aside tem a caixa de login, ou, se logado, "Olá, <email>" com links para a Minha Conta e um botão de logout POST. Tem também o "Top 5 Level". Depois vem o `<footer>`.

CSS:
- Fundo do body: `linear-gradient(#0b1026 0%, #1d2240 35%, #3a2a1a 75%, #2b1d10 100%)` mais `url(../img/castelo.svg)` em `no-repeat top center`. O `castelo.svg` é uma silhueta escura, pintada à mão como paths simples, só decorativa.
- Logo: `color:#e8c46a` com `-webkit-text-stroke:1px #3b2208` e `text-shadow` marrom-escuro.
- Menu e caixas laterais: `background:#2b1d10; border:2px solid #8a6326`, links `#e8c46a`.
- Pergaminho: `background:linear-gradient(#f3e2b8,#e2c98f); color:#2b1d10`, título `background:#5a3c16; color:#f3e2b8`.
- Botões:
  - dourado: `linear-gradient(#b8862b,#7a5414)`, texto `#fff` em negrito, `font-size:1.2rem` (texto grande para WCAG, contraste ≥ 3:1) e `text-shadow:0 1px 1px #000`;
  - verde: `#3a6b2a` com texto branco.
- Foco: `:focus-visible{outline:3px solid #ffd96a; outline-offset:2px}`.
- Layout: grid `230px minmax(0,1fr) 250px` com gap 18px e `max-width:1200px`. Em `@media (max-width: 900px)` vira `grid-template-columns:1fr` e as colunas empilham na ordem do DOM: menu, conteúdo, lateral.
- Tabelas com `overflow-x:auto` num wrapper.
- Todo `<input>` tem `<label for>`. Os erros aparecem em `<div class="erros" role="alert">` e ao lado do campo.

Se houver `<img>`, ela leva `alt`. Hoje o castelo é um background de CSS, então não há nenhuma `<img>` obrigatória.

**Headers de segurança** (no bootstrap, valem também no `php -S`):
- `X-Content-Type-Options: nosniff`;
- `X-Frame-Options: DENY`;
- `Referrer-Policy: same-origin`;
- `Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'`. Sem inline style nem script: o CSS fica todo no arquivo;
- `Content-Type: text/html; charset=utf-8`.

**Erros e log.** O bootstrap configura:
- `error_reporting(E_ALL)`, `ini_set('display_errors','0')`, `log_errors=1` e `error_log=storage/logs/php-error.log`;
- `date_default_timezone_set(timezone)`;
- `set_exception_handler`, que registra CRITICAL em `storage/logs/app.log` (classe, mensagem, arquivo:linha, sem trace de argumentos) e, se os headers ainda não saíram, devolve 500 com a página "Algo deu errado. Tente novamente em instantes."; senão, só o parágrafo genérico.

`app_log` grava `[Y-m-d H:i:s] LEVEL mensagem {json ctx}` com `FILE_APPEND|LOCK_EX`. É proibido logar senha, hash ou email. O contexto leva `ip` e `account_id`.

## Validação de entradas

| Entrada | Obrigatória | Regras | Falha |
|---|---|---|---|
| `_csrf` (todo POST) | sim | string, `hash_equals` com a sessão | 400 + página "sessão expirou", nada gravado |
| email (cadastro) | sim | trim, minúsculas, ≤ 255, `filter_var(FILTER_VALIDATE_EMAIL)` sem flag unicode (garante ASCII, compatível com a coluna utf8mb3) | "Informe um email válido." |
| email (login) | sim | trim, 1–255, sem checar formato | "Email ou senha incorretos." |
| senha (cadastro/nova) | sim | string, 8–64 caracteres (`mb_strlen`), igual à confirmação | "A senha precisa ter de 8 a 64 caracteres." / "As senhas não conferem." |
| senha (login/atual) | sim | 1–256 | genérico |
| nome do personagem | sim | `normalize_char_name`: trim e depois `ucwords(strtolower())`. Validação: `^[A-Za-z]+( [A-Za-z]+)*$`, 3–20 caracteres. Nenhuma palavra (ci) em {god, gm, cm, sample}. Único (checado no banco + UNIQUE) | "O nome deve ter de 3 a 20 letras, com espaços simples." / "Este nome é reservado." / "Este nome já está em uso." |
| vocação | sim | string de dígitos e chave em `config.samples` (1, 2, 3, 4, 9) | "Escolha uma vocação válida." |
| sexo | sim | "0" ou "1" (0 = feminino, 1 = masculino) | "Escolha o sexo do personagem." |
| `skill` (GET ranking) | não | chave em `SKILL_COLUMNS` | cai em `level`, sem erro |
| título da notícia | sim | trim, 3–120 caracteres | "O título deve ter de 3 a 120 caracteres." |
| texto da notícia | sim | trim, 1–5000 caracteres | "O texto deve ter até 5000 caracteres." |
| id da notícia (apagar) | sim | `ctype_digit` e > 0 | ignorado, com flash "Notícia não encontrada." |
| `action` (POST Minha Conta) | sim | um de `login`, `logout`, `create_char`, `change_password`, `post_news`, `delete_news` | 400 genérico |

O helper `post_str($key, $max)` devolve '' se o valor não for string, como no caso de arrays. Valores acima do limite são rejeitados pela validação, não truncados em silêncio. Duplos espaços no nome são rejeitados pela regex, sem colapsar automaticamente, para ficar previsível. Como a normalização capitaliza ("joao da silva" → "Joao Da Silva"), o nome final aparece na mensagem de sucesso.

## Invariantes e quem as garante

- **Todo POST tem CSRF válido.** Garantido pelo bootstrap, que executa antes de qualquer página.
- **Nenhuma conta sem personagem e nenhum personagem órfão no cadastro.** Garantido pela transação em `repo_accounts.php`.
- **Nome de personagem único.** Garantido pelo banco (UNIQUE em players.name). A checagem prévia em PHP só serve para dar uma mensagem amigável.
- **Email único.** Garantido pelo repositório (`SELECT … FOR UPDATE` dentro da transação), já que o banco não tem UNIQUE e não vou alterar o schema do Canary.
- **No máximo 10 personagens por conta.** Garantido pelo repositório (`COUNT … FOR UPDATE` na transação).
- **Ranking e Top 5 sem staff nem Sample.** Garantido pela função única `ranking()`.
- **A senha nunca aparece em saída ou log.** Garantido por `lua_config.php`, que lança exceções só com o nome da chave, e por `app_log`, que nunca recebe senha nem hash (regra de código, checada na revisão).
- **Só contas com type >= 5 publicam ou apagam notícias.** Garantido pelo handler da Minha Conta, que relê `type` do banco a cada ação.
- **O login.php e o MyAAC ficam intactos.** É uma restrição de processo: nenhum arquivo em `C:\xampp\htdocs` é editado. Comparo o hash SHA256 do login.php antes e depois e registro no relatório.

## Tratamento de erros por operação

| Operação | Falha | Tipo | Resposta ao usuário | Log |
|---|---|---|---|---|
| Ler config.php | ausente/inválido | fatal | 500 "Algo deu errado…" | CRITICAL (php-error.log, porque o app_log depende da config) |
| Parse do config.lua | arquivo/chave ausente | fatal | 503 "Site temporariamente indisponível." | CRITICAL com o nome da chave |
| Conectar ao banco | PDOException | fatal na página | 503 "Site temporariamente indisponível." | ERROR com `getCode()` e mensagem do PDO (não contém a senha) |
| Caixa de status / Top 5 | erro de query | recuperável | caixa com "—" | ERROR |
| TCP 7171 | falha/timeout | recuperável (estado esperado) | "Offline" | nenhum |
| Gravar o cache de status | falha de I/O | recuperável | segue sem cache | WARNING |
| Rate limit | pasta não gravável | recuperável (fail-open) | segue normalmente | ERROR |
| Rate limit | excedido | recuperável | "Muitas tentativas… N minutos." / "Limite de cadastros por hora atingido. Tente mais tarde." | WARNING `ratelimit bucket=… ip=…` |
| Cadastro | validação | recuperável | formulário reexibido com erros (sem as senhas) | nenhum |
| Cadastro | 23000 (corrida no nome) | recuperável | erro no campo nome | INFO |
| Cadastro / criar personagem | sample ausente | recuperável para o usuário (erro de config) | "Não foi possível criar o personagem agora. Tente mais tarde." | ERROR `sample ausente` |
| Cadastro / criar personagem | outro PDOException | recuperável | mesma mensagem genérica, rollback | ERROR |
| Login | credencial inválida | recuperável | "Email ou senha incorretos." | nenhum (o hit fica no rate limit) |
| Sessão | conta removida, senha alterada, idle | recuperável | sessão encerrada, form de login, flash "Sua sessão expirou." | nenhum |
| Troca de senha | atual errada | recuperável | "Senha atual incorreta." | nenhum (hit no bucket login) |
| Notícias | tabela ausente | recuperável | "Notícias indisponíveis no momento." | ERROR |
| Publicar/apagar notícia | sem permissão | recuperável | 403 "Acesso negado." | WARNING |
| CSRF | inválido/ausente | recuperável | 400 "Sua sessão expirou…" | INFO |
| Exceção não tratada | qualquer | fatal | 500 genérico | CRITICAL |

## Casos de borda
- Contas com email fora do padrão (ex.: sem domínio) são aceitas, pois o login não valida formato.
- Senha de banco vazia é aceita pelo parser e pelo PDO.
- O Monk é suportado (id 9 e o "Monk Sample" existem). Se o sample sumir no futuro, a vocação continua no form e a criação mostra o erro genérico, com log ERROR que identifica o sample.
- Personagens com o mesmo nome em caixa diferente ("joao" vs "Joao") colidem pela normalização e pela collation ci.
- Nome "Gmail Rei" é aceito (a palavra "gmail" ≠ "gm"). "Gm Joao", "Sample" e "Joao God" são rejeitados.
- Lista de online vazia, ranking vazio e notícias vazias têm mensagens próprias.
- Usuário logado acessando `criar-conta.php` vê o aviso "Você já está logado", com link para a Minha Conta, onde cria personagens.
- POST sem cookie de sessão (primeira visita direto por POST) falha no CSRF e recebe 400.
- Quando o Apache ainda não foi reiniciado, a 7180 continua servindo o MyAAC. O relatório deixa isso explícito.
- O `php -S` não tem `/login.php`. O teste do jogo usa `http://127.0.0.1/login.php`, na porta 80, que não muda.
- Download com `download_url` vazio ou sem https mostra "Link em breve". Com URL válida, mostra `<a class="btn-ouro" href="<e(url)>" rel="noopener noreferrer">Baixar Client</a>`.
- O botão "Baixar Client" da home leva a `download.php`, e não direto ao Drive, para o estado "Link em breve" ficar num único lugar.

## Testabilidade

**Unitários (`php site\tests\run.php`, asserts sem framework, saída "OK n testes" ou falha com exit 1):**
- `parse_lua_db_config`: amostra com pass vazio, comentários e porta ausente, a partir de um arquivo temporário em `sys_get_temp_dir()`, apagado ao final;
- `validate_email`, `validate_password`, `normalize_char_name` e `validate_char_name`: nomes reservados, dígitos, duplo espaço, limites 2/3/20/21;
- whitelist do ranking (chave inválida → level);
- rate limit: diretório temporário, `max` atingido, limpeza de janela com timestamps antigos gravados no arquivo e `rl_clear`;
- `e()`: escapa `<>"'&`.

Essas funções são puras ou recebem o caminho e a config por parâmetro. O rate limit recebe o diretório e a config como argumentos, com wrappers de conveniência no bootstrap, justamente para permitir o teste.

**Integrados (`site\tests\smoke.ps1 -Base http://127.0.0.1:<porta>`), contra o `php -S` e, depois do restart, contra `http://192.168.0.100:7180`:**
- GET das 6 páginas: status 200, sem "Warning", "Notice", "Fatal" ou "Deprecated" no corpo e sem `http://`/`//` em `href`/`src` internos;
- CSS: 200 com `text/css`;
- POST sem token em `criar-conta.php`: 400, e a contagem de `accounts` não muda;
- cadastro com o email `teste<ts>@tiozaoot.test`, senha de teste e nome sem dígitos gerado com letras (ex.: "Teste" + sufixo de letras derivado do timestamp);
- conferência no banco: hash de 40 caracteres hex e vocation/town/looktype iguais aos do sample;
- casos inválidos do AC 6;
- logout, login (o cookie TIOZAOSID muda) e personagem visível;
- troca de senha, login com a nova e falha com a antiga;
- logout;
- POST JSON em `http://127.0.0.1/login.php` com a conta de teste: o personagem aparece;
- 6 logins errados (o 6º é bloqueado), seguidos de `rl_clear` do IP 127.0.0.1 com `php -r`, para não deixar o usuário bloqueado;
- `bin\delete-test-account.php --email=…`;
- a regressão do login.php nas duas URLs.

**Pós-restart, só no Apache:**
- `GET /assets/` → 403 ou 404, sem listagem;
- `GET /../app/bootstrap.php` e `GET /app/bootstrap.php` → 404 ou 400;
- `GET /login.php` (POST de regressão) → `191.13.180.9:7172`.

O `delete-test-account.php` (CLI) recusa qualquer email que não termine em `@tiozaoot.test`. Ele conta contas e personagens antes, apaga numa transação (`player_items`, `players` e `accounts` só dos ids da conta de teste) e verifica que o total de `accounts` caiu exatamente 1 e o de `players` caiu exatamente o número de personagens da conta. Se não bater, faz rollback.

## Ordem de execução para o implementador
1. Backup do banco: `mysqldump --single-transaction canary > E:\Amigos_OT\backups\canary_backup_<ts>.sql`, sem senha na linha de comando (hoje ela é vazia; se não fosse, passaria por `MYSQL_PWD` no ambiente). Depois, o hash SHA256 do login.php.
2. Criar a árvore `site\`, `php -l` em todos os arquivos e `php site\tests\run.php`.
3. `php site\bin\install.php` (cria e semeia a `site_news`).
4. `php -S 127.0.0.1:8091 -t E:\Amigos_OT\site\public`, em background (se a porta estiver ocupada, a próxima livre). Depois, `smoke.ps1`, a regressão do login.php e as screenshots via `msedge --headless=new --disable-gpu --window-size=1366,900 --screenshot=<path>` e `--window-size=390,844`, salvas em `E:\Amigos_OT\canary\.agents\tasks\screenshots\site-home-desktop.png` e `site-home-mobile.png`. Encerrar o `php -S`.
5. Backup do `httpd-vhosts.conf`, acrescentar o bloco, rodar `httpd.exe -t` (precisa dar "Syntax OK"; se não der, restaurar o backup) e repetir a regressão (inalterada, porque não houve reload).
6. Escrever o relatório em pt-BR (`site-proprio-report.md`) com tudo o que o AC 20 pede. A pendência de reiniciar o Apache vai explícita, junto com os testes pós-restart que o usuário (ou um passo seguinte) deve rodar. Opções futuras de TLS: Cloudflare Tunnel com hostname fixo, certificado Let's Encrypt via duckdns (`tiozaoot.duckdns.org`, que já é o ServerName) em uma porta liberada, ou proxy reverso com TLS.

## Fora do escopo (reafirmado)
- Alterações no MyAAC, no login.php ou no Canary, e restart do Canary.
- TLS.
- Recuperação de senha, verificação de email e captcha.
- Paginação do ranking.
- Uptime.
- Editar notícias (só publicar e apagar).
- Varredura periódica dos arquivos de rate limit e rotação de logs.
