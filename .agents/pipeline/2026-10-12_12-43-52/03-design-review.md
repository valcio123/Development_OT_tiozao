# Revisão do design: site próprio "Clássico Medieval" (TiozaoOT)

Revisado: `02-design.md` contra `01-requirements.md` e o brief `canary\.agents\tasks\site-proprio-brief.md`. As afirmações sobre o ambiente foram conferidas no Apache, no MyAAC, no config.lua, no código do Canary e no banco `canary` (somente leitura).

Veredito: **CHANGES_REQUESTED** (1 HIGH, 5 MEDIUM, 8 NIT)

## Findings

### 1. HIGH: o backup do banco via `>` no PowerShell 5.1 sai corrompido
Onde: "Ordem de execução", passo 1 (`mysqldump --single-transaction canary > E:\Amigos_OT\backups\canary_backup_<ts>.sql`).
Problema: o shell da máquina é o Windows PowerShell 5.1.26100 (conferido). Nele, `>` regrava a saída de um comando nativo em UTF-16LE com BOM, depois de decodificá-la como texto. O `mysql` não restaura um arquivo UTF-16. E os blobs (`players.conditions`, `player_items.attributes`) são bytes arbitrários, que a decodificação pode mutilar. Esse dump é o único rollback de um banco de produção. Os dumps que já existem em `backups\` começam com `2D 2D 20 4D` ("-- M", UTF-8), então foram gerados de outro jeito.
Correção: não redirecionar pelo PowerShell. Fazer o mysqldump gravar o arquivo direto e serializar os blobs em hex:
```powershell
$ts = Get-Date -Format yyyyMMdd_HHmmss
$out = "E:\Amigos_OT\backups\canary_backup_$ts.sql"
& C:\xampp\mysql\bin\mysqldump.exe -uroot --single-transaction --routines --triggers --hex-blob --default-character-set=utf8mb4 "--result-file=$out" canary
if ($LASTEXITCODE -ne 0) { throw "mysqldump falhou" }
# verificação: primeiros bytes "-- " (não FF FE) e última linha contendo "Dump completed"
```
Se a senha não for vazia, passá-la por `$env:MYSQL_PWD`, nunca na linha de comando.

### 2. MEDIUM: falta a seção "Como jogar" (RF8.2)
Onde: o design não especifica o conteúdo de `download.php`, só o botão e o estado "Link em breve".
Correção: incluir na seção Download:
> `download.php` mostra o botão (ou "Link em breve") e, abaixo, `<h2>Como jogar</h2>` com um `<ol>` de 4 itens: "Baixe o client pelo botão acima."; "Extraia o arquivo .zip numa pasta (ex.: Área de Trabalho)."; "Abra o `otclient.exe`."; "Entre com o email e a senha da sua conta (crie em Criar Conta)." O texto é estático no template, sem input do usuário.

### 3. MEDIUM: a checagem de warnings do AC 2 nunca falha
Onde: "Testabilidade/Integrados" ("sem Warning, Notice, Fatal ou Deprecated no corpo") combinado com "Erros e log" (`display_errors=0`, `error_log=storage/logs/php-error.log`).
Problema: com `display_errors=0`, warnings e notices nunca aparecem no corpo. O teste passa mesmo que todas as páginas emitam notices, e o AC 2 fica sem verificação real.
Correção: o `smoke.ps1` mede o tamanho de `storage\logs\php-error.log` e de `storage\logs\app.log` antes dos GETs. Depois deles, falha se aparecer qualquer linha nova com `PHP (Warning|Notice|Deprecated|Fatal error)` ou `CRITICAL`. Manter também a checagem do corpo, que pega erros anteriores ao bootstrap.

### 4. MEDIUM: gatilho contraditório para o fallback `/site`
Onde: "Integração com o Apache". Uma frase diz "Se o resultado [do `httpd -t`] for diferente, restauro o backup e uso o fallback". A outra diz "Fallback (RF1.3), usado só se a raiz falhar depois do restart".
Correção: uma regra só:
> (a) Se o `httpd -t` falhar com o bloco do vhost: restaurar o backup, aplicar o bloco do fallback (`Alias /site` + `<Directory>`) e rodar o `httpd -t` de novo. Se falhar outra vez, restaurar o backup, não deixar nenhuma mudança no Apache e reportar.
> (b) Se o `httpd -t` passar: manter o vhost. A troca para o fallback depois do restart é decisão do usuário, e o relatório traz o bloco pronto para colar e o procedimento.

### 5. MEDIUM: assinaturas e semântica dos helpers indefinidas ou conflitantes
Onde: "Estrutura de arquivos" (lista nomes sem assinatura), "Rate limit" (`rl_exceeded(bucket, ip)`) e "Testabilidade" ("o rate limit recebe o diretório e a config como argumentos, com wrappers no bootstrap"). O `post_str($key, $max)` diz receber `$max`, mas a mesma seção diz que valores acima do limite "são rejeitados pela validação, não truncados". Não fica claro o que `post_str` faz com `$max`, nem se faz trim. Fazer trim na senha quebraria o login do jogo para senhas com espaço nas pontas.
Correção: fixar:
```php
// security.php
function post_str(string $key): string;          // '' se ausente/não-string; SEM trim, SEM corte
// validation.php: devolvem null se ok, ou a mensagem de erro pt-BR
function validate_email(string $raw, ?string &$normalized): ?string;   // trim+lower dentro
function validate_password(string $pw, string $confirm): ?string;      // sem trim
function normalize_char_name(string $raw): string;
function validate_char_name(string $normalized): ?string;              // formato + reservados (não checa unicidade)
// ratelimit.php: núcleo testável
function rl_exceeded_at(string $dir, string $bucket, string $ip, int $max, int $window, ?int $now = null): bool;
function rl_hit_at(string $dir, string $bucket, string $ip, int $window, ?int $now = null): void;
function rl_clear_at(string $dir, string $bucket, string $ip): void;
function rl_retry_after_at(string $dir, string $bucket, string $ip, int $window, ?int $now = null): int;
// wrappers usados pelas páginas: rl_exceeded($bucket, $ip) etc., que leem dir/limites da config
```
Regra: o trim acontece só nos validadores de email, nome, título e texto de notícia. Senhas nunca passam por trim. Os limites de tamanho ficam nos validadores.

### 6. MEDIUM: falha de banco no layout sem regra (503 x "—")
Onde: "Tratamento de erros". "Conectar ao banco → fatal na página, 503" e "Caixa de status / Top 5 → recuperável, '—'". O header e o footer abrem conexão (status e Top 5) em todas as páginas, inclusive em `download.php`, que não precisa de banco. Também não está definido se a página consulta o banco antes ou depois de chamar `render_header`. Se a falha vier depois do header, não dá mais para mandar 503.
Correção: regra explícita:
> Cada página faz toda a leitura e escrita de banco **antes** de `render_header()` e captura `PDOException` (inclusive de conexão) para responder 503. Os widgets do layout (status, Top 5, saudação do login) chamam `db()` dentro de `try/catch (Throwable)` e mostram "—" em caso de falha, com um único log ERROR por requisição. `download.php` e a página de erro nunca dão 503 por causa do banco. O `db()` guarda a falha de conexão para não tentar de novo na mesma requisição.

### 7. NIT: "FOR UPDATE bloqueia cadastros concorrentes" está impreciso
Onde: "Criação de conta", passo 1, e "Invariantes/Email único".
Problema: em REPEATABLE READ, dois `SELECT … FOR UPDATE` sem resultado pegam gap locks compatíveis entre si. Os dois `INSERT` seguintes entram em deadlock, e um deles leva o erro 1213 (SQLSTATE 40001). Duplicata não acontece, mas o perdedor cai em "outro PDOException" e recebe a mensagem genérica.
Correção: no catch, tratar `errorInfo[1] === 1213` ou SQLSTATE `40001` como "Este email já está cadastrado.", depois do rollback. Corrigir o texto do design para "o deadlock resultante impede a duplicata".

### 8. NIT: o login por email não define qual linha usar
Onde: "Login e sessão", passo 2. `email` não é UNIQUE (índice `accounts_email`, não-único, conferido).
Correção: `SELECT id, password, type FROM accounts WHERE email = ? ORDER BY id LIMIT 1`.

### 9. NIT: `session_idle` de 2 h não vale com o GC padrão
Onde: "Login e sessão". O PHP do XAMPP usa `session.gc_maxlifetime=1440` (24 min) e gc 1/1000 (conferido). Sessões ociosas por mais de 24 min podem ser coletadas antes das 2 h.
Correção: no bootstrap, antes do `session_start()`: `ini_set('session.gc_maxlifetime', (string)$config['session_idle']);`.

### 10. NIT: rodar o smoke de novo esbarra no limite de cadastro
Onde: "Testabilidade". O smoke limpa só o bucket `login`. Cada execução cria 1 conta a partir de 127.0.0.1, e o limite é 3 por hora.
Correção: ao final do smoke (e no início, para idempotência), rodar `rl_clear('register','127.0.0.1')` além de `rl_clear('login','127.0.0.1')`.

### 11. NIT: `httpd -t` escreve "Syntax OK" no stderr
Onde: "Ordem de execução", passo 5. No PS 5.1, `2>&1` transforma essa saída em `NativeCommandError` (conferido), o que pode ser lido como falha.
Correção: `$o = & C:\xampp\apache\bin\httpd.exe -t 2>&1 | Out-String; $ok = ($LASTEXITCODE -eq 0) -and ($o -match 'Syntax OK')`.

### 12. NIT: fato errado sobre as contas existentes
Onde: "Fatos verificados". Existem contas existentes, todas com `type = 6`. Pela regra `type >= 5`, todas podem publicar e apagar notícias.
Correção: corrigir o fato e listar no relatório quais contas têm permissão de publicar, para o usuário confirmar.

### 13. NIT: contraste do botão de login não especificado
Onde: "Layout e visual". Branco sobre #b8862b dá cerca de 3,2:1. Isso só passa como texto grande, e o design só garante `1.2rem` bold para o botão "dourado" da home.
Correção: o botão "Entrar" da caixa de login usa a mesma classe `.btn-ouro` (bold, ≥ 1.2rem, `text-shadow`) ou texto `#2b1d10` sobre o gradiente.

### 14. NIT: o "ponto online/offline" do brief não está especificado
Onde: "Status do servidor" e "Layout". O brief pede um ponto de status.
Correção: `<span class="dot dot-on|dot-off" aria-hidden="true"></span> Online|Offline`, com o texto sempre presente (a cor não é o único indicador). CSS: `.dot-on{background:#3fbf3f}` e `.dot-off{background:#b33}`.

## Verified Assumptions
- `httpd.conf`: `Listen 80/8080/7180`, `DocumentRoot "C:/xampp/htdocs"`, `<Directory />` com `Require all denied`, htdocs com `Require all granted` e `AllowOverride All`, mod_alias e mod_rewrite carregados, `Include conf/extra/httpd-vhosts.conf`. O `httpd-vhosts.conf` só tem comentários. `httpd -S` mostra só o vhost *:443 do SSL. O `httpd -t` atual dá "Syntax OK".
- Não existe `.htaccess` em `C:\xampp\htdocs` (só `.htaccess.dist`). O `AllowOverride All` do htdocs, portanto, não interfere no Alias de `/login.php`.
- `login.php` faz `require_once 'common.php'`. `common.php` define `BASE = __DIR__ . '/'`, e `system/base.php` deriva `BASE_DIR` de `SCRIPT_NAME` (`/login.php` → ''). Não há uso de `DOCUMENT_ROOT` em `system/`. O Alias preserva os includes.
- O IP da world vem de `$_SERVER['REMOTE_ADDR']` (login.php, linhas 116–118). O login.php não escreve no banco no fluxo de senha (o RateLimit do MyAAC usa cache). `account_mail_verify` tem padrão false e não está sobrescrito em `myaac_settings`, então as contas novas com `email_verified=0` entram no jogo.
- config.lua: credenciais do banco (host/user/senha/database/port) no `config.lua` local, que **não é versionado**; `serverName="TiozaoOT"`, `statusProtocolPort=7171` (igual à loginProtocolPort), `passwordType="sha1"`, `authType="password"`. A regex do parser não casa `mysqlDatabaseBackup`.
- Canary: `loadByEmailOrName` busca por `email` (protocolo novo). A senha é comparada com `transformToSHA1(password) == getPassword()`. As contas têm hash de 40 caracteres hex minúsculos.
- `accounts`: InnoDB utf8_general_ci; `name` varchar(32) UNIQUE, NOT NULL sem default; `password` NOT NULL sem default; `email` com índice não-único e sem duplicatas hoje; `key`, `created`, `rlname`, `location`, `country`, `type`, `premdays`, `lastday` e `creation` têm default.
- `players`: `name` UNIQUE (`players_unique`); `conditions` mediumblob NOT NULL sem default; todas as colunas do INSERT do design existem (incluindo `created`, `balance`, `deletion`, `lookaddons`, `stamina` e as `skill_*`); índice em `account_id`.
- Samples ids 1–6 (Rook, Sorcerer, Druid, Paladin, Knight, Monk), conta 1, group 1, sex 1, looktype 129, town 8 (Thais), exceto o Rook (town 1). Cada um tem 1 linha em `player_items` (11/101/23396).
- Vocações 0–10 batem com `vocations.xml`. O Monk tem id 9.
- `server_config.players_record` existe (valor 1). `players_online` só tem `player_id` (ENGINE=MEMORY). Não existe `site_news`.
- Todas as FKs para `players` e `accounts` são `ON DELETE CASCADE`. Apagar a conta de teste não deixa órfãos em tabelas com FK.
- MyAAC `CreateCharacter.php`: usa looktype 136 para o feminino, posição 0/0/0, balance 0 e copia `player_items` do sample. Ressalva: o MyAAC usa o town de `character_towns` e copia skills só se `use_character_sample_skills` estiver ativo. O design copia town e skills do sample. Hoje o resultado é o mesmo (town 8, como em todos os personagens existentes).
- PHP 8.2.12 com PDO, pdo_mysql, mbstring, openssl e session. MariaDB 10.4.32 em REPEATABLE-READ. O Edge existe no caminho indicado. `E:\Amigos_OT\backups\` existe.

## Unverified/Wrong Assumptions
- **Errado:** a contagem de contas existentes (finding 12).
- **Errado:** o `FOR UPDATE` "bloqueia" cadastros concorrentes do mesmo email. Na prática gera deadlock no perdedor (finding 7).
- **Errado (no ambiente):** o `mysqldump … > arquivo` produz um dump válido. No PowerShell 5.1, não produz (finding 1).
- **Não verificado:** o comportamento do vhost e do Alias depois do restart do Apache. Só pode ser confirmado quando o usuário reiniciar. O design já trata isso como pendência.
- **Não verificado:** se algum túnel externo (Cloudflare) aponta para a porta 7180. Não há processo `cloudflared` rodando agora. O `site_url` do MyAAC aponta para um trycloudflare morto, o que não afeta o site novo.
- **Não verificado:** a renderização das screenshots headless do Edge (`--screenshot` com `--headless=new`) nesta versão do Edge.
