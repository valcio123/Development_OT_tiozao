# Smoke/integração do site próprio do TiozaoOT.
# Uso (servidor php -S embutido, sobe e derruba sozinho):
#   powershell -ExecutionPolicy Bypass -File tests\smoke.ps1
# Contra o Apache (já rodando):
#   powershell -ExecutionPolicy Bypass -File tests\smoke.ps1 -Base http://localhost:7180 -NoServer
#
# Cobre os critérios de aceite automatizáveis. Não modifica o MyAAC/login.php nem o Canary.

[CmdletBinding()]
param(
    [string]$Base     = 'http://127.0.0.1:8091',
    [string]$GameBase = 'http://127.0.0.1',
    [string]$Php      = 'C:\xampp\php\php.exe',
    [string]$Mysql    = 'C:\xampp\mysql\bin\mysql.exe',
    [string]$SiteDir  = 'E:\Amigos_OT\site',
    [string]$CanaryLua = 'E:\Amigos_OT\canary\config.lua',
    [switch]$NoServer
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$PublicDir = Join-Path $SiteDir 'public'
$LogDir    = Join-Path $SiteDir 'storage\logs'
$RlDir     = Join-Path $SiteDir 'storage\ratelimit'

$Email    = 'smoke.teste@tiozaoot.test'
$Pass     = 'SenhaSegura123'
$NewPass  = 'NovaSenha456'
$CharName = 'Smoke Teste'
$VocId    = 1                       # Sorcerer
$Sample   = 'Sorcerer Sample'

$script:okCount = 0; $script:failCount = 0; $script:skipCount = 0

function Check([bool]$cond, [string]$label) {
    if ($cond) { $script:okCount++; Write-Host "  ok   - $label" -ForegroundColor Green }
    else       { $script:failCount++; Write-Host "  FAIL - $label" -ForegroundColor Red }
}
function Skip([string]$label) { $script:skipCount++; Write-Host "  skip - $label" -ForegroundColor Yellow }
function Section([string]$name) { Write-Host "`n# $name" -ForegroundColor Cyan }

# sha1 hex minúsculo, igual ao gravado pelo site no banco
function sha1_lower([string]$s) {
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
    return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLower()
}

# --- MySQL -----------------------------------------------------------------
$rawLua = Get-Content -Raw $CanaryLua
$m = [regex]::Match($rawLua, 'mysqlPass\s*=\s*("([^"]*)"|''([^'']*)'')')
$env:MYSQL_PWD = if ($m.Success) { if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $m.Groups[3].Value } } else { '' }

function DbScalar([string]$sql) {
    $out = & $Mysql -uroot -D canary --batch -N -e $sql 2>$null
    return (($out | Out-String).Trim())
}
function DbRow([string]$sql) {
    $out = & $Mysql -uroot -D canary --batch -e $sql 2>$null
    return $out
}

function Clear-RateLimit {
    if (Test-Path $RlDir) { Get-ChildItem -Path $RlDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
}

# --- HTTP ------------------------------------------------------------------
function Invoke-Req {
    param([string]$Method, [string]$Url, $Body, $Session, [string]$ContentType)
    $p = @{ Uri = $Url; Method = $Method; UseBasicParsing = $true; TimeoutSec = 30 }
    if ($Session) { $p.WebSession = $Session }
    if ($null -ne $Body) { $p.Body = $Body }
    if ($ContentType) { $p.ContentType = $ContentType }
    try {
        $r = Invoke-WebRequest @p
        return [pscustomobject]@{ Status = [int]$r.StatusCode; Content = $r.Content; Raw = $r }
    } catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $status = [int]$resp.StatusCode
            $body = ''
            try { $body = $_.ErrorDetails.Message } catch {}
            if (-not $body) {
                try { $sr = New-Object IO.StreamReader($resp.GetResponseStream()); $body = $sr.ReadToEnd() } catch {}
            }
            return [pscustomobject]@{ Status = $status; Content = $body; Raw = $null }
        }
        throw
    }
}
function Get-Csrf([string]$html) {
    $mm = [regex]::Match($html, 'name="_csrf"\s+value="([0-9a-f]+)"')
    if ($mm.Success) { return $mm.Groups[1].Value }
    return $null
}
function SidOf($Session) {
    try { return ($Session.Cookies.GetCookies([uri]$Base) | Where-Object { $_.Name -eq 'TIOZAOSID' } | Select-Object -First 1).Value } catch { return $null }
}

$Forbidden = @('Warning:', 'Notice:', 'Deprecated:', 'Fatal error', 'Uncaught', 'Stack trace', 'stack trace:', 'Xdebug')
function Has-Forbidden([string]$html) {
    foreach ($f in $Forbidden) { if ($html -like "*$f*") { return $f } }
    return $null
}
function Has-AbsoluteUrl([string]$html) {
    return ([regex]::IsMatch($html, '(?i)(?:href|src)\s*=\s*["''](?:https?:)?//'))
}

# --- Bootstrap do servidor --------------------------------------------------
$server = $null
try {
    Clear-RateLimit

    $accBefore = [int](DbScalar 'SELECT COUNT(*) FROM accounts')
    $plyBefore = [int](DbScalar 'SELECT COUNT(*) FROM players')
    $sampleRow = DbRow "SELECT id,vocation,town_id,looktype FROM players WHERE name='$Sample'"
    $sampleVals = ($sampleRow | Select-Object -Skip 1 | Select-Object -First 1) -split '\s+'
    $sampleId = [int]$sampleVals[0]; $sampleVoc = [int]$sampleVals[1]; $sampleTown = [int]$sampleVals[2]; $sampleLook = [int]$sampleVals[3]
    $sampleItems = [int](DbScalar "SELECT COUNT(*) FROM player_items WHERE player_id=$sampleId")

    $logMarker = 0
    if (Test-Path "$LogDir\app.log") { $logMarker = (Get-Content "$LogDir\app.log" | Measure-Object -Line).Lines }
    $errMarker = 0
    if (Test-Path "$LogDir\php-error.log") { $errMarker = (Get-Content "$LogDir\php-error.log" | Measure-Object -Line).Lines }

    if (-not $NoServer) {
        $parts = ([uri]$Base)
        $bind = "$($parts.Host):$($parts.Port)"
        $server = Start-Process -FilePath $Php -ArgumentList @('-S', $bind, '-t', $PublicDir) -PassThru -WindowStyle Hidden
        $ready = $false
        for ($i = 0; $i -lt 60; $i++) {
            try { $null = Invoke-WebRequest "$Base/index.php" -UseBasicParsing -TimeoutSec 2; $ready = $true; break }
            catch { Start-Sleep -Milliseconds 250 }
        }
        if (-not $ready) { throw "servidor php -S não respondeu em $Base" }
    }

    # --- 2) GET das páginas -------------------------------------------------
    Section '2) Páginas retornam 200 e sem erros'
    $pages = @('index.php', 'criar-conta.php', 'minha-conta.php', 'ranking.php', 'online.php', 'download.php')
    $htmls = @{}
    foreach ($pg in $pages) {
        $r = Invoke-Req GET "$Base/$pg" $null $null
        $htmls[$pg] = $r.Content
        Check ($r.Status -eq 200) "$pg responde 200 (veio $($r.Status))"
        $f = Has-Forbidden $r.Content
        Check ($null -eq $f) "$pg sem warnings/erros no corpo"
        Check (-not (Has-AbsoluteUrl $r.Content)) "$pg sem URL absoluta com host"
    }
    Check ($htmls['index.php'] -like '*TiozaoOT*') 'index contém o nome do servidor'
    Check ($htmls['index.php'] -like '*Servidor aberto*') 'index mostra a notícia semeada'

    # --- 2b) CSS ------------------------------------------------------------
    $css = Invoke-Req GET "$Base/assets/css/style.css" $null $null
    Check ($css.Status -eq 200) 'CSS responde 200'
    $ct = ''
    if ($css.Raw) { $ct = [string]$css.Raw.Headers['Content-Type'] }
    Check ($ct -like 'text/css*') "CSS content-type text/css (veio '$ct')"
    Check ($css.Content -like '*:focus-visible*') 'CSS define :focus-visible'

    # --- 4) CSRF ------------------------------------------------------------
    Section '4) POST sem CSRF é rejeitado'
    $accNow = [int](DbScalar 'SELECT COUNT(*) FROM accounts')
    $r = Invoke-Req POST "$Base/criar-conta.php" @{ email = 'nocsrf@tiozaoot.test'; password = $Pass; confirm = $Pass; name = 'No Csrf'; vocation = '1'; sex = '1' } $null
    Check ($r.Status -eq 400) "POST sem token → 400 (veio $($r.Status))"
    Check ([int](DbScalar 'SELECT COUNT(*) FROM accounts') -eq $accNow) 'nenhuma conta criada sem CSRF'

    # --- 5) Cadastro --------------------------------------------------------
    Section '5) Cadastro com CSRF cria conta + personagem'
    $s1 = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $g = Invoke-Req GET "$Base/criar-conta.php" $null $s1
    $tok = Get-Csrf $g.Content
    Check ($null -ne $tok) 'token CSRF obtido'
    $sidBefore = SidOf $s1
    $r = Invoke-Req POST "$Base/criar-conta.php" @{ _csrf = $tok; email = $Email; password = $Pass; confirm = $Pass; name = $CharName; vocation = "$VocId"; sex = '1' } $s1
    Check ($r.Status -eq 200) "cadastro redireciona e renderiza (veio $($r.Status))"
    Check ($r.Content -like "*$CharName*") 'Minha Conta lista o personagem recém-criado'

    $accId = DbScalar "SELECT id FROM accounts WHERE email='$Email'"
    Check (-not [string]::IsNullOrWhiteSpace($accId)) 'conta existe no banco'
    $pwHash = DbScalar "SELECT password FROM accounts WHERE email='$Email'"
    Check ($pwHash -ceq (sha1_lower $Pass)) 'senha gravada em SHA1 hex minúsculo'
    $pRow = DbRow "SELECT vocation,town_id,looktype FROM players WHERE name='$CharName'"
    $pv = ($pRow | Select-Object -Skip 1 | Select-Object -First 1) -split '\s+'
    Check ([int]$pv[0] -eq $sampleVoc) 'vocação igual à do Sample'
    Check ([int]$pv[1] -eq $sampleTown) 'town igual à do Sample'
    Check ([int]$pv[2] -eq $sampleLook) 'looktype masculino igual ao Sample'
    $playerId = [int](DbScalar "SELECT id FROM players WHERE name='$CharName'")
    Check ([int](DbScalar "SELECT COUNT(*) FROM player_items WHERE player_id=$playerId") -eq $sampleItems) 'itens copiados do Sample'

    # --- 6) Entradas inválidas ---------------------------------------------
    Section '6) Entradas inválidas são recusadas'
    function RegisterExpect([string]$label, [hashtable]$fields, [string]$needle) {
        $s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $g = Invoke-Req GET "$Base/criar-conta.php" $null $s
        $t = Get-Csrf $g.Content
        $fields['_csrf'] = $t
        $r = Invoke-Req POST "$Base/criar-conta.php" $fields $s
        Check (($r.Status -eq 200) -and ($r.Content -like "*$needle*")) "$label"
    }
    $accNow = [int](DbScalar 'SELECT COUNT(*) FROM accounts')
    RegisterExpect 'email duplicado recusado' @{ email = $Email; password = $Pass; confirm = $Pass; name = 'Outro Nome'; vocation = '1'; sex = '1' } 'já está cadastrado'
    RegisterExpect 'senha curta recusada' @{ email = 'curta@tiozaoot.test'; password = '1234567'; confirm = '1234567'; name = 'Senha Curta'; vocation = '1'; sex = '1' } '8 a 64'
    RegisterExpect 'confirmação diferente recusada' @{ email = 'conf@tiozaoot.test'; password = $Pass; confirm = 'OutraSenha9'; name = 'Conf Difere'; vocation = '1'; sex = '1' } 'não conferem'
    RegisterExpect 'nome com dígitos recusado' @{ email = 'dig@tiozaoot.test'; password = $Pass; confirm = $Pass; name = 'Nome123'; vocation = '1'; sex = '1' } 'letras'
    RegisterExpect 'nome reservado recusado' @{ email = 'res@tiozaoot.test'; password = $Pass; confirm = $Pass; name = 'God Plus'; vocation = '1'; sex = '1' } 'reservado'
    RegisterExpect 'nome duplicado recusado' @{ email = 'dup@tiozaoot.test'; password = $Pass; confirm = $Pass; name = $CharName; vocation = '1'; sex = '1' } 'já está em uso'
    Check ([int](DbScalar 'SELECT COUNT(*) FROM accounts') -eq $accNow) 'nenhuma das tentativas inválidas gravou conta'

    # --- 7/8) Login, sessão, troca de senha, logout -------------------------
    Section '7/8) Login, troca de senha e logout'
    $s2 = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s2
    $tok = Get-Csrf $g.Content
    $sidAnon = SidOf $s2
    $r = Invoke-Req POST "$Base/minha-conta.php" @{ _csrf = $tok; action = 'login'; email = $Email; password = 'errada123' } $s2
    Check ($r.Content -like '*incorretos*') 'login com senha errada mostra erro'
    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s2
    $tok = Get-Csrf $g.Content
    $r = Invoke-Req POST "$Base/minha-conta.php" @{ _csrf = $tok; action = 'login'; email = $Email; password = $Pass } $s2
    Check ($r.Status -eq 200) 'login correto redireciona/rende'
    Check ($r.Content -like "*$CharName*") 'personagem aparece na Minha Conta logada'
    $sidAuth = SidOf $s2
    Check ($sidAnon -ne $sidAuth) 'ID de sessão muda após o login'

    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s2
    $tok = Get-Csrf $g.Content
    $r = Invoke-Req POST "$Base/minha-conta.php" @{ _csrf = $tok; action = 'change_password'; current = $Pass; new = $NewPass; confirm = $NewPass } $s2
    Check ($r.Status -eq 200) 'troca de senha processada'
    $pwHash2 = DbScalar "SELECT password FROM accounts WHERE email='$Email'"
    Check ($pwHash2 -ceq (sha1_lower $NewPass)) 'nova senha gravada'

    $s3 = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s3
    $tok = Get-Csrf $g.Content
    $r = Invoke-Req POST "$Base/minha-conta.php" @{ _csrf = $tok; action = 'login'; email = $Email; password = $Pass } $s3
    Check ($r.Content -like '*incorretos*') 'login com a senha antiga falha'
    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s3
    $tok = Get-Csrf $g.Content
    $r = Invoke-Req POST "$Base/minha-conta.php" @{ _csrf = $tok; action = 'login'; email = $Email; password = $NewPass } $s3
    Check ($r.Content -like "*$CharName*") 'login com a nova senha funciona'

    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s3
    $tok = Get-Csrf $g.Content
    $null = Invoke-Req POST "$Base/minha-conta.php" @{ _csrf = $tok; action = 'logout' } $s3
    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s3
    Check ($g.Content -like '*name="password"*') 'logout encerra a sessão (volta a pedir login)'

    # --- 9/12) Login do jogo via login.php ----------------------------------
    Section '9/12) login.php do jogo'
    try {
        $json = (@{ type = 'login'; email = $Email; password = $NewPass } | ConvertTo-Json -Compress)
        $lr = Invoke-Req POST "$GameBase/login.php" $json $null 'application/json'
        $obj = $null
        try { $obj = $lr.Content | ConvertFrom-Json } catch {}
        if ($null -ne $obj -and $null -ne $obj.playdata) {
            Check ($obj.playdata.worlds[0].externaladdressprotected -eq '127.0.0.1') 'externaladdressprotected = 127.0.0.1 (loopback)'
            $names = @($obj.playdata.characters | ForEach-Object { $_.name })
            Check ($names -contains $CharName) 'login.php devolve o personagem de teste'
        } else {
            Check $false "login.php respondeu playdata (veio: $($lr.Content.Substring(0,[Math]::Min(140,$lr.Content.Length))))"
        }
    } catch { Skip "login.php indisponível ($($_.Exception.Message))" }

    # --- 10) Rate limit de login -------------------------------------------
    Section '10) Rate limit de login'
    Clear-RateLimit
    $s4 = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $g = Invoke-Req GET "$Base/minha-conta.php" $null $s4
    $last = $null
    for ($i = 1; $i -le 6; $i++) {
        $tok = Get-Csrf $g.Content
        $last = Invoke-Req POST "$Base/minha-conta.php" @{ _csrf = $tok; action = 'login'; email = $Email; password = 'errada123' } $s4
        $g = $last
    }
    Check ($last.Content -like '*Muitas tentativas*') '6ª tentativa é bloqueada por rate limit'
    Clear-RateLimit

    # --- 15) Ranking --------------------------------------------------------
    Section '15) Ranking'
    $rk = Invoke-Req GET "$Base/ranking.php?skill=sword" $null $null
    Check ($rk.Status -eq 200) 'ranking com skill=válida responde 200'
    Check (-not ($rk.Content -like '*Sample*')) 'ranking não lista Samples'
    $rk2 = Invoke-Req GET "$Base/ranking.php?skill=xx%27%20OR%201=1" $null $null
    Check ($rk2.Status -eq 200) 'ranking com skill inválida responde 200 (fallback level)'

    # --- 17) Download -------------------------------------------------------
    Section '17) Download'
    $dl = Invoke-Req GET "$Base/download.php" $null $null
    Check ($dl.Content -like '*Link em breve*') 'Download mostra "Link em breve" sem URL configurada'
    Check ($dl.Content -like '*Como jogar*') 'Download tem a seção "Como jogar"'

    # --- 20) Não servir arquivos sensíveis ---------------------------------
    Section '20) Config/includes/logs não são servidos'
    foreach ($p in @('config/config.php', 'app/bootstrap.php', 'storage/logs/app.log')) {
        $r = Invoke-Req GET "$Base/$p" $null $null
        Check (($r.Status -ne 200) -and ($r.Content -notlike '*<?php*')) "$p não é servido (status $($r.Status))"
    }

    # --- 19) Acessibilidade -------------------------------------------------
    Section '19) Acessibilidade básica'
    $cacc = Invoke-Req GET "$Base/criar-conta.php" $null $null
    $inputs = ([regex]::Matches($cacc.Content, '<input[^>]*type="(text|password)"')).Count
    $labels = ([regex]::Matches($cacc.Content, '<label[^>]*for=')).Count
    Check ($labels -ge $inputs) "todo input tem label associada ($labels labels / $inputs inputs)"

    # --- 11) Cleanup --------------------------------------------------------
    Section '11) Remoção da conta de teste'
    $d = & $Php (Join-Path $SiteDir 'bin\delete-test-account.php') "--email=$Email" 2>&1
    Check ($LASTEXITCODE -eq 0) "delete-test-account exit 0 (saída: $d)"
    Check ([int](DbScalar 'SELECT COUNT(*) FROM accounts') -eq $accBefore) 'contagem de accounts voltou ao inicial'
    Check ([int](DbScalar 'SELECT COUNT(*) FROM players') -eq $plyBefore) 'contagem de players voltou ao inicial'

    # --- 2) logs ------------------------------------------------------------
    Section '2) Logs sem novos ERROR/CRITICAL'
    $newErr = @()
    if (Test-Path "$LogDir\app.log") {
        $newErr += (Get-Content "$LogDir\app.log" | Select-Object -Skip $logMarker) | Where-Object { $_ -match '\b(ERROR|CRITICAL)\b' }
    }
    if (Test-Path "$LogDir\php-error.log") {
        $newErr += (Get-Content "$LogDir\php-error.log" | Select-Object -Skip $errMarker)
    }
    Check ($newErr.Count -eq 0) "sem novas linhas de erro nos logs ($($newErr.Count) encontrada(s))"
}
finally {
    Clear-RateLimit
    if ($env:MYSQL_PWD -ne $null) { Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue }
    if ($server) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n==== $($script:okCount) ok, $($script:failCount) falha(s), $($script:skipCount) skip ===="
exit $(if ($script:failCount -eq 0) { 0 } else { 1 })
