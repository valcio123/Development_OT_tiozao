# Modo de combate tradicional

## Configuração

`modernCombatSystem = true` mantém as regras existentes. `false` aplica as
restrições tradicionais deste documento. O padrão e a configuração local
continuam em `true`. A chave é lida na inicialização: mudar o arquivo e executar
reload não troca o modo. É necessário um reinício controlado do servidor.

O executável antigo não reconhece essa chave; é necessário compilar o código
alterado. O cliente continua usando o protocolo atual. Essa opção não converte
o servidor inteiro, o mapa ou as fórmulas de dano para Tibia 7.4.

## Cooldown e magias

Todas as magias e runas permitidas compartilham 2000 ms, incluindo cura,
ataque, suporte, conjuração e comandos de casa. Depois de um uso bem-sucedido,
as três condições padrão de grupo e a condição individual recebem 2000 ms.
As condições de grupo também atualizam os indicadores do cliente. Taxa de
cooldown, equipamento, Momentum, roda e limpeza de cooldown não reduzem esse
intervalo no modo tradicional. Falhas não consomem a nova condição.

A política está em `src/creatures/combat/combat_mode.hpp`. O bloqueio ocorre
antes do privilégio IgnoreSpellCheck. Os registros Lua originais permanecem
intactos: reiniciar em modo moderno restaura disponibilidade e cooldowns.
`canCast`, `isEnabled`, a lista Lua usada pelo spellbook e a lista enviada ao
cliente aplicam a mesma restrição.

### Auditoria da lista

Referência histórica: [catálogo Avesta 7.4/7.6/7.7](https://github.com/peonso/avesta74/blob/master/data/spells/spells.xml),
comparado com os nomes registrados em `data/scripts/spells` e `data/scripts/runes`.
A lista é uma seleção conservadora das correspondências existentes, não uma
reimplementação completa do catálogo histórico. Nomes são comparados por
igualdade completa sem distinguir maiúsculas e minúsculas.

Correspondências de nome incluem Antidote → Cure Poison; Invisible →
Invisibility; Conjure Poison Arrow → Conjure Poisoned Arrow; nomes de runas
passam a incluir o sufixo Rune. O Energy Wave conserva a implementação atual,
cuja fórmula verbal mudou. Custos, vocações, níveis, cargas e efeitos existentes
continuam como no Canary, exceto o cooldown e as formulas tradicionais de UH,
GFB, Avalanche e Thunderstorm descritas neste documento.

Não são liberadas automaticamente versões modernas de magias históricas com
efeitos diferentes: Death Strike não substitui Force Strike; Rage of the Skies
não substitui Ultimate Explosion; Stalagmite não substitui Envenom; Wild Growth
Rune não substitui a antiga magia instantânea Wild Growth. Essas correspondências
exigem uma decisão posterior. Poison Storm e Undead Legion não têm implementação
equivalente entre as magias instantâneas importadas. Magias não listadas ficam
bloqueadas, incluindo strikes modernos, familiares e magias Monk. Avalanche e
Thunderstorm foram liberadas por decisao explicita do usuario em 12/10/2026.

## Monk e personagens

As vocações 9 (Monk) e 10 (Exalted Monk) permanecem no banco e na lista da conta.
O preload lê o ID da vocação e o protocolo rejeita o login com mensagem antes
de `loadPlayerById` e `placeCreature`. Reconexões são verificadas novamente.
Nenhum DELETE, UPDATE ou conversão de personagem é necessário.

## Itens e NPCs

Uso normal e uso em alvo/hotkey verificam a mesma política central. São bloqueados
os IDs de poções de cura, mistas, mana superior e o dispenser aleatório:
236, 237, 238, 239, 266, 6558, 7642, 7643, 7876, 23373, 23374, 23375.
Comidas de recuperação imediata de vida/mana bloqueadas:
9079, 9086, 11586, 11587, 28484, 28485, 29414, 29415.

Mana potion comum (268) mantém a exaustão existente de itens; não recebe o
cooldown de magias. Comidas comuns mantêm a regeneração. Poções de atributos,
antídoto e comidas sem recuperação imediata não estão no bloqueio solicitado.

A janela de comércio recebe uma cópia filtrada. Compra, venda e venda em lote
também verificam a política, incluindo pacotes enviados diretamente pelo cliente.
Os catálogos originais não são removidos; o modo moderno restaura o comércio.

## UH: referências e fórmula selecionada

Consulta em 12/10/2026. `L` é level e `ML` é magic level.

| Base | Fórmula encontrada | Observação |
| --- | --- | --- |
| [Avesta 7.4/7.6](https://github.com/peonso/avesta74/blob/master/data/spells/scripts/healing/ultimate_healing_rune.lua) | mínimo = max(250, 2,1 × (2L + 3ML)); máximo = 2,5 × (2L + 3ML) | O código histórico pode produzir mínimo maior que máximo em níveis baixos; não copiar sem corrigir e aprovar. |
| [Nostalrius UH](https://github.com/Ezzz-dev/Nostalrius/blob/master/data/spells/scripts/runes/ultimate%20healing.lua) e [helper](https://github.com/Ezzz-dev/Nostalrius/blob/master/data/spells/lib/spells.lua) | mínimo = máximo = 2,5 × max(100, 2L + 3ML) | Piso 250, resultado fixo antes de modificadores do combate. A base é 7.7 e está arquivada; não é prova oficial da fórmula da CipSoft 7.4. |
| [Nekiro TFS 1.5, 7.72](https://github.com/nekiro/TFS-1.5-Downgrades/blob/7.72/data/spells/scripts/runes/ultimate_healing_rune.lua) | mínimo = L/5 + 7,3ML + 42; máximo = L/5 + 12,4ML + 90 | Coincide com a fórmula atual importada do Canary; protocolo antigo não garante fórmula antiga. |

A referência mais recente [TVP develop](https://github.com/TVPV8/TVP/blob/4fbdacb2c226d58483f5d18d650ad0ab56ee9809/gameserver/data/scripts/spells/runes/ultimate_healing_rune.lua)
chama `computeHealing(250, 0, true)`. O helper não foi localizado nos arquivos
de implementação consultados; essa chamada isolada não basta para afirmar a
equação completa. Não foi compilado nem executado nenhum projeto externo.

O usuário selecionou Nostalrius: mínimo = máximo = 2,5 × max(100, 2L + 3ML).
O callback da UH aplica essa equação somente no modo tradicional; o modo moderno
conserva a fórmula original. A cura base é fixa; modificadores existentes do
combate (equipamentos, roda e outros buffs) ainda podem afetar a cura final.

## Validação

- Teste `tests/unit/game/combat_mode_test.cpp`: restauração de todos os IDs de
  itens/vocações no modo moderno; bloqueio dos dois Monks; mana/comida comum;
  rejeição de nomes modernos, prefixos e entradas desconhecidas.
- Teste Lua `tests/lua/traditional_uh_test.lua`: executa o callback real da UH
  com stubs de registro, validando piso, scaling, restauração moderna e ciclos
  entre os dois valores da configuração.
- Execução isolada sem GTest: compilar esse teste com `COMBAT_MODE_STANDALONE`,
  C++20 e include path `src`. As assertions devem ficar habilitadas.
- Compilar o servidor pelo preset `windows-release`, conforme
  `docs/building/local-validation.md`, e conferir dependências Ninja.
- Validação em jogo ainda necessária: tentativa de ataque/cura/suporte/runa
  antes e depois de 2000 ms; potion durante exaustão de magia; listas do cliente;
  compra via janela/pacote; login das duas vocações nos dois modos; ciclos
  moderno → tradicional → moderno com reinício e sem alteração do banco.
- Conferir os valores recebidos pelo cliente, inclusive qualquer bot que tenha
  catálogo de magias próprio: enforcement do servidor é independente desse catálogo.

Nenhum servidor em execução foi reiniciado para validar esta alteração.

### Resultado local em 12/10/2026

- Build `windows-release` concluída com MSVC/Ninja; execução incremental final
  sem trabalho pendente. Dependências de spells, protocolo e actions registram
  `combat_mode.hpp` com status VALID.
- Teste de política compilado com MSVC C++20 e executado com assertions: passou.
- Teste do callback real da UH executado com LuaJIT: passou.
- Executável gerado: `canary.exe`. O executável anterior foi preservado em backup.
- O cache importado foi preservado em `build/windows-release.imported`; o preset
  local reutilizou suas dependências já instaladas, sem downloads de pacotes.
- Testes GTest completos e validação em jogo não foram executados.
- Nenhum banco foi alterado e nenhum processo do servidor original foi reiniciado.

### Correção do primeiro teste em jogo

- GFB (3191, great fireball rune) é permitida em ambos os modos e tem teste de regressão específico.
- Avisos de item bloqueado agora identificam nome/ID e são enviados uma vez por item durante a vida da instância Player. Tentativas seguintes continuam bloqueadas, mas não renovam o aviso do cliente. A mensagem permite identificar qual item ou hotkey está realmente sendo recusado.
- A actionbar do OTClient aplica cooldown de grupo também às runas. Pacotes genéricos de uso de itens não encurtam nem reiniciam um cooldown mais longo já ativo; uma extensão substitui o evento antigo de remoção.
- Teste Lua `custom/otclient/tests/lua/actionbar_cooldown_test.lua` cobre GFB/UH, ordenação de pacotes, extensão de timer e independência da mana potion.
- Aplicação: usar o novo executável Canary e atualizar o arquivo Lua da actionbar no cliente em uso, reiniciando o cliente. A retestagem visual em jogo continua necessária.

O executável desta correção é gerado em `build/windows-release/bin/canary.exe`
com a opção mantida `TOGGLE_BIN_FOLDER=ON`, pois o executável da raiz está em uso
pelo teste. É necessário encerrar o servidor de forma controlada e iniciar o
novo executável com `custom/canary` como diretório de trabalho; o cliente em uso
também precisa ser reiniciado para carregar a actionbar corrigida.

### Area rune damage calibration (2026-10-12)

User-approved traditional exceptions: Avalanche (3161) and Thunderstorm (3202)
are available alongside Great Fireball (3191), with the shared 2000 ms exhaustion.
These three runes share `getTraditionalAreaRuneDamage` in
`data/libs/functions/combat.lua`: base = 2 * level + 3 * effective magic level;
minimum = base * 0.35 * class factor; maximum = base * 0.65 * class factor.
Factors: Sorcerer/Druid 1.00, Paladin 0.75, Knight 0.60. Base vocation IDs cover
promotions. The callback returns negative values for damage; integer conversion
and subsequent combat modifiers remain handled by the engine.

Each caster uses their own ML. The calibration targets RP around half the mage
damage and EK around 30% below RP, rather than exactly those percentages for
arbitrary character skills. With the agreed example MLs at levels 50 through 400,
RP ranges from 43.4% to 61.1% of mage damage, and EK from 34.1% to 25.9% below RP.
All three retain their original element, area, requirements and modern formula.
This is a custom balance choice, not a claim of historical 7.4 availability.

Validation: `tests/lua/traditional_area_runes_test.lua` executes the three real
callbacks and shared library, checking class factors, own level/ML scaling,
mode cycles and restoration of the original modern formulas. The C++ policy
test checks availability of both newly allowed runes. In-game testing remains
necessary for final damage after target resistance and other combat modifiers.

Local validation completed: LuaJIT area rune, UH and client actionbar tests passed;
standalone MSVC policy assertions and the `windows-release` build passed.
The executable was installed at `custom/canary/canary.exe` after a verified backup
and graceful shutdown/save. Restart from `custom/canary` confirmed server online
with `modernCombatSystem = false` and no Lua loading errors. Full GTest and
in-game damage/element/cooldown verification were not performed.

### Movimento com paralyze

No modo tradicional, runas de ataque e cura ignoram apenas a exaustão de passo
do paralyze nos cinco pontos de entrada/execução do uso de itens. O personagem
continua lento, e alcance, alvo, paredes, custos e cooldown de combate permanecem
validados. A exaustão de itens/poções e o comportamento do modo moderno são preservados.
O teste de política cobre a separação para runas e a preservação dos demais itens.
