# TiozaoOT — Registro de progresso

Projeto: servidor Canary (fork do OTServBR-Global) + client OTClient Redemption, customizados como "TiozaoOT", rodando localmente no Windows.

## Estrutura do workspace

```
e:\Amigos_OT\
├── canary\     -- código-fonte do servidor (C++ / Lua)
└── otclient\   -- código-fonte do client (C++ / Lua)
```

## 1. Pesquisa inicial sobre compatibilidade de client

- Confirmado via `src/core.hpp` do Canary: `CLIENT_VERSION = 1525` (protocolo 15.25), o perfil "Current" moderno.
- Verificado em `docs/systems/multiprotocol.md`: existe um perfil `ProtocolProfileId::OTCv8Extended860` reservado para OTCv8, mas está **bloqueado/não implementado** (falta transporte, challenge e payload). Logo, **OTCv8 não é compatível** com este servidor.
- Client oficialmente suportado pelo projeto: **OTClient Redemption** (`github.com/opentibiabr/otclient`), que é compatível com o protocolo 15.25 nativamente.

## 2. Clonagem dos repositórios

- `git clone https://github.com/opentibiabr/canary.git` → `e:\Amigos_OT\canary`
- `git clone https://github.com/opentibiabr/otclient.git` → `e:\Amigos_OT\otclient`

Ambos eram apenas código-fonte, sem executáveis — precisaram ser compilados.

## 3. Ambiente de build (ferramentas instaladas)

Verificado no sistema (Windows/PowerShell):
- Git ✅ já instalado
- Visual Studio 18 Insiders (toolset v145) ✅ já instalado
- XAMPP com MariaDB 10.4.32 ✅ já instalado e rodando (porta 3306)
- CMake, Ninja, vcpkg ❌ não estavam instalados

Instalado via winget:
- `winget install jdx.mise` — gerenciador de ferramentas (usado para instalar cmake, ninja, sccache nas versões pinadas pelo `.mise.toml` do Canary)
- `mise install` dentro de `canary/` → instalou `cmake@4.3.4`, `ninja@1.13.2`, `sccache@0.14.0`, `python@3.14.6`
- `mise run bootstrap` → clonou o vcpkg pinado em `canary/.tools/vcpkg`
- Variável de ambiente de usuário `VCPKG_ROOT` definida para `E:\Amigos_OT\canary\.tools\vcpkg` (necessária para a integração vcpkg do Visual Studio)

Tentativa inicial de configurar via terminal (`cmake --preset windows-release`) foi iniciada mas abandonada em favor de compilar direto pelo Visual Studio.

## 4. Compilação do servidor (Canary)

- Build feita pelo **Visual Studio**, usando a solution clássica (não o fluxo CMake-presets):
  - Projeto aberto: `e:\Amigos_OT\canary\vcproj\canary.sln`
  - Configuração: Debug | x64
  - O build acionou a instalação automática das dependências vcpkg (24 pacotes: abseil, argon2, asio, curl, libmariadb, luajit, mbedtls, nlohmann-json, protobuf, pugixml, spdlog, zlib, etc.) via integração MSBuild/vcpkg manifest.
  - Tempo total: baixou, compilou e instalou todas as dependências antes de compilar os ~150+ arquivos `.cpp` do Canary.
- **Resultado:** `e:\Amigos_OT\canary\canary-sln-dbg.exe` gerado com sucesso, junto com as DLLs necessárias na mesma pasta (`abseil_dll.dll`, `argon2.dll`, `fmt.dll`, `libcurl.dll`, `libmariadb.dll`, `libprotobuf-lite.dll`, `lua51.dll`, `pugixml.dll`, `z.dll`).

## 5. Banco de dados

- Banco MariaDB dedicado criado no XAMPP: `canary` (separado de outros bancos já existentes como `tiozaodb`).
- Schema importado: `canary/schema.sql` → 48 tabelas criadas com sucesso (`mysql.exe -u root canary < schema.sql`).
- Credenciais do XAMPP: usuário padrão de desenvolvimento local, sem senha.

## 6. Configuração do servidor (`config.lua`)

- Criado a partir de `config.lua.dist` (arquivo `config.lua` não existia ainda).
- Alterações principais: conexão MySQL apontando para o XAMPP local; as credenciais ficam no `config.lua`, que **não é versionado**.
  ```lua
  serverName = "TiozaoOT"
  serverMotd = "Welcome to TiozaoOT!"
  ```
- Demais configurações mantidas no padrão do `.dist` (worldType = "retro-pvp", portas 7171/7172, download automático do mapa oficial do OTServBR-Global na primeira execução, etc.)

**Nota de segurança:** credenciais de banco sem senha são aceitáveis apenas para ambiente local isolado, e não devem ser levadas para qualquer cenário de exposição externa/produção sem revisão.

## 7. Servidor rodando

- `canary-sln-dbg.exe` executado com sucesso.
- Confirmado via `netstat`: portas `7171` (login/status) e `7172` (jogo) em `LISTENING`.

## 8. Compilação do client (OTClient)

- Build feita pelo Visual Studio, solution clássica:
  - Projeto aberto: `e:\Amigos_OT\otclient\vc18\otclient.sln`
  - Mesma integração vcpkg via MSBuild, porém com dependências mais pesadas (abseil, **angle** — implementação OpenGL/gráfica, zlib, etc.), build mais demorada que a do servidor.
- **Resultado:** executável do client gerado e já aberto com sucesso pelo usuário (ex: `otclient.exe` em `e:\Amigos_OT\otclient\vc18\otclient\x64\Debug\`).

## 9. Customização de branding ("TiozaoOT")

### Servidor (`canary/config.lua`)
```lua
serverName = "TiozaoOT"
serverMotd = "Welcome to TiozaoOT!"
```

### Client (`otclient/init.lua`)
- Tabela `Servers_init` reduzida para uma única entrada, removendo a lista de servidores/campos de host/porta da tela de login (comportamento nativo do `entergame.lua`: quando há exatamente 1 servidor configurado, a UI esconde esses campos e vira tela de login dedicada):
  ```lua
  Servers_init = {
      ["127.0.0.1"] = {
          port = 7171,
          protocol = 1525,
          httpLogin = false
      }
  }
  ```
- Nome/identidade do app:
  ```lua
  g_app.setName("TiozaoOT");
  g_app.setCompactName("tiozaoot");
  g_app.setOrganizationName("TiozaoOT");
  ```
  Isso também muda a pasta de configurações salvas (`%APPDATA%\tiozaoot\` em vez de `otclient\`) e o nome do arquivo de log (`tiozaoot.log`).

**Pendente/opcional:** troca do ícone do executável (`src/otcicon.ico`, `cmake/icon/otcicon.ico`) e da imagem de fundo da tela de login (`/images/background`) — ainda não feito.

## 10. Erro de assets (dat/spr) — investigado, causa identificada

Ao abrir o client, apareceu erro:
```
Unable to load dat file, please place a valid dat in '/data/things/0/Tibia.dat'
Unable to load spr file, please place a valid spr in '/data/things/0/Tibia.spr'
```

**Causa raiz (confirmada no código):**
- Os arquivos visuais do jogo (sprites/dados de itens) não vêm no repositório — são conteúdo com direitos de imagem da CipSoft, não redistribuível em forks open-source.
- O client faz um **preload automático em background** (`modules/game_things/things.lua` + lógica em `client_bottommenu`) para exibir a imagem do "boosted creature" assim que abre, **antes do login**. Essa tentativa falha (nenhum asset instalado ainda) e o código cai no fallback `setClientVersion(0)`, por isso o erro mostra `things/0/` em vez de `things/1525/`.
- Esse erro de preload **não bloqueia o login**.

**Mecanismo de correção já existente no client:**
- `init.lua` já tem configurado `Services.clientAssets` apontando para o repositório `dudantas/tibia-client` no GitHub.
- Em `modules/client_entergame/entergame.lua`, a função `EnterGame.doLogin()` verifica, para protocolo ≥ 1281, se os assets da versão estão instalados (`client_assets.isClientVersionInstalled`) e, se não estiverem, dispara `client_assets.ensureClientVersion()` — que baixa e instala os assets automaticamente antes de completar o login (mostra uma janela "Downloading Assets" com barra de progresso).

**Próximo passo (ainda não executado/confirmado):** tentar logar (OK no erro, digitar conta/senha, clicar Entrar) para disparar o download automático de assets da versão 1525 e confirmar se o repositório `dudantas/tibia-client` tem um pacote compatível com essa versão exata.

## Estado atual

- ✅ Servidor Canary compilado e rodando (`canary-sln-dbg.exe`, portas 7171/7172 ativas)
- ✅ Banco de dados `canary` criado e schema importado
- ✅ Client OTClient compilado e abrindo
- ✅ Branding customizado para "TiozaoOT" em ambos os lados
- ⏳ Pendente: confirmar download automático dos assets gráficos (dat/spr) e primeiro login bem-sucedido
- ⏳ Pendente (opcional): ícone customizado e imagem de fundo da tela de login
