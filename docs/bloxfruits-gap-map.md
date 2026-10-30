# Blox Fruits — mapa de gaps (Etapa 2)

Estado do backend Blox Fruits contra o plano de evolução (§2–§11).
Legenda: **Impl** = implementada (mecanismo real existe) ·
**Auto** = testada automaticamente (suite headless) · **Game** = testada in-game ·
**Gap** = falta configuração/controle para algo que o plano pede ·
**N/A** = não implementável de forma confiável (motivo registrado).

Como o painel se monta: o módulo OSS chama `UI.toggle/slider/dropdown/button`
→ `ui-headless.register` grava em `page.controls` → backend
(`bloxfruits.lua` `applySea`) renderiza cada definição no painel. O getter de
cada definição lê o estado vivo, então **tudo que é registrado já entra no
Save/Load** (via `Core.gatherConfig`). Adicionar config = adicionar a chamada
`UI.*` com callback que muta o estado e getter que o lê.

---

## 2. FARM (prioridade máxima)

Arquivo: `src/games/features/bloxfruits/oss/farm.lua`
Controles atuais: `buildFarm` (linhas ~655–708), 3 páginas (Farm/Farm 2/Farm 3).

### Configurações gerais
| Pedido no plano | Estado | Onde / nota |
|---|---|---|
| Método de movimentação | **Impl** | só tween-fly (`teleport.go`); não há escolha |
| Distância desejada do NPC | **Impl** Auto | slider "Approach distance" → `hoverRange` (30–600) |
| Altura de posicionamento | **Impl** Auto | `heightOffset` (slider 0–40) |
| Velocidade de movimentação | **Impl** | `teleport.config.speed`, sem controle no Farm |
| Intervalo de atualização | **Gap** | `questInterval` está declarado mas **nunca é lido** (config morta) — não virou controle |
| Intervalo de ataque | **Impl** Auto | slider "Attack interval" → `attackInterval` (0.05–2s) |
| Alcance de detecção | **Impl** | usa `combat.config.range` (slider "Attack range") |
| Alcance de ataque | **Impl** Auto | slider "Attack range" 1–300 → `combat.config.range` |
| Comportamento ao perder alvo | **Impl** | `_farmStep` retargeta (nearest/spawn); não precisa de controle |
| Comportamento ao morrer | **Impl** | loop `if not h then return end` idles; sem controle (sem alternativa real) |
| Retomada após respawn | **Impl** | retoma sozinho quando `hrp()` volta + watchdog reinicia loop >4s |
| Evitar ficar preso | **Impl** | RenderStepped: `Anchored=false` + `AssemblyLinearVelocity=0` por frame |

> Nota: `ui-headless` `UI.slider` arredondava **todo** valor para inteiro, o que
> tornava inalcançável a faixa fracionária (ex.: 0.05–2s). Corrigido: só arredonda
> quando min/max são inteiros, preservando precisão em sliders fracionários.

### Sistemas de farm
| Pedido | Estado | Nota |
|---|---|---|
| Auto Level Farm | **Impl** Auto | `setFarm` |
| Farm Nearest | **Impl** Auto | `setNearestFarm` |
| Auto Next Island | **Impl** | `setAutoNextIsland` |
| Farm Boss | **Impl** Auto | `setBossFarm` + dropdown de boss |
| Material Farm | **Impl** Auto | `setMaterialFarm` + dropdown |
| Auto Saber | **Impl** | toggle em `buildFarm` |
| Farm de maestria | **Gap** | não existe |
| Farm de frutas | **Impl** | coleta de frutas no `_farmStep` (sem config) |
| Farm de espadas / armas | **Gap** | não existe (Sword/Gun só como equipType) |

### Combate durante o farm
| Pedido | Estado | Nota |
|---|---|---|
| Escolher arma | **Impl** | `equipType` (Melee/Sword/Gun/Fruit) |
| Tipo de arma | **Impl** | mesmo dropdown |
| Selecionar habilidades | **Gap** | skills ficam no Combat, sem seleção por farm |
| Configurar teclas | **Impl** | `combat.config.keys` (no PVP) |
| Intervalo entre habilidades | **Impl** | `combat.config.clickInterval` (no PVP) |
| Alternância automática de armas | **Gap** | não existe |
| Configuração de alcance | **Impl** Auto | "Attack range" |
| Básico vs habilidades | **Gap** | usa o que o Combat tiver ligado |

### NPCs
| Pedido | Estado | Nota |
|---|---|---|
| Seleção de NPC/quest | **Impl** | dropdown "Quest" |
| Seleção de ilha | **Impl** | via teleport (islands); sem dropdown no Farm |
| Prioridade de alvo | **Gap** | sempre o mais próximo do tipo |
| Distância máx. p/ achar NPC | **Impl** | `hoverRange` (sem controle) |
| Agrupamento | **Impl** | `bring` toggle |
| Bring Mob | **Impl** Auto | `bring` |
| Máx. de NPCs processados | **Gap** | processa 1 por tick |

### Atributos
| Pedido | Estado | Nota |
|---|---|---|
| Seleção de atributo | **Impl** Auto | dropdown "Stat" |
| Quantidade por distribuição | **Impl** Auto | slider "Amount" 1–100 |
| Distribuição automática | **Impl** Auto | "Auto add points" |
| Limite de pontos | **Gap** | sem alvo máximo |
| Parar ao atingir o valor | **Gap** | não existe |

**Resumo Farm:** a rodada fechou os gaps de config de risco baixo — `hoverRange`
("Approach distance") e `attackInterval` ("Attack interval") viraram sliders reais
com testes de ida-e-volta (chegam ao `M.config` e ao Save/Load). Perder alvo,
morrer e retomar após respawn **já eram** comportamento real do loop, então não
ganharam controle (não há alternativa sensata a expor). `questInterval` é config
morta (nunca lida) e ficou sem controle — não vou fingir que funciona. Gaps de
sistema (maestria, espadas/armas, prioridade de alvo, alternância de armas,
limite de pontos) seguem pendentes para depois do básico validado.

---

## 3. PVP

Arquivo: `combat.lua`. Já existe base ampla: `range`, `delay`,
`targetPlayers`/`playerRange`, `auraRange`, `losCheck`, `aimSmooth`,
`clickInterval`, `keys{Z,X,C,V,F}`, `followDist`, `attack1v1`, `bounty{...}`.

| Pedido | Estado | Nota |
|---|---|---|
| Auto Attack: alcance/intervalo/arma/habilidades | **Impl** | `range`,`delay`,`clickInterval`,`keys` |
| Auto Attack: atacar durante o farm | **Impl** | `combat.attackOnce` usado pelo farm |
| Kill Aura: alcance / LOS / intervalo | **Impl** | `auraRange`,`losCheck`,`delay` |
| Kill Aura: seleção/prioridade de alvos | **Parcial** | `targetPlayers` mas sem filtros |
| Aimbot: suavidade | **Impl** | `aimSmooth` (slider) |
| Aimbot: alcance máximo | **Impl** Auto | slider "Aimbot range" → `aimRange` (20–1000) |
| Aimbot: parte do corpo | **Impl** Auto | dropdown "Aim part" → `aimPart` (Root/Head/Upper/LowerTorso) |
| Aimbot: ativação por tecla | **Gap** | ainda só toggle (`aim`); sem bind de tecla |
| Auto Skills: teclas / intervalo | **Impl** | `keys` + `clickInterval` |
| Auto Skills: ordem de execução | **Impl** Auto | textbox "Skill order" → `skillOrder`; **bug corrigido**: era `pairs()` (ordem aleatória), agora segue a sequência |
| Auto Bounty: equipes / método / ignorar amigos | **Impl** | `bounty.noFriends`,`bounty.safePct`,`bounty.method`,`bounty.team` |
| Auto Bounty: mensagem / tempo máx / retirada | **Impl** | `bounty.chatKill`,`chatMsg`,`maxTime` |
| Auto Bounty: lista personalizada de ignorados | **Impl** Auto | textbox "Ignore players" → `bounty.ignore` (nome ou display, vírgula/espaço) |
| Follow Nearest / Spectate / No Stun / 1v1 | **Impl** | `followDist`, `attack1v1`, etc. |
| Invisible from Ken | **Impl** | `bounty.invisKen`|

**Resumo PVP:** a rodada fechou lista de ignorados (bounty), alcance e parte do
corpo do aimbot e a ordem de skills — e corrigiu um bug real (a rotação de skills
saía em ordem aleatória por usar `pairs()`). Único gap de PVP restante: **bind de
tecla do aimbot** (hoje só toggle) — exige hook de `UserInputService` que ainda
não existe no módulo; fica pendente até haver mecanismo.

---

## 4. FRUITS

Arquivo: `fruits.lua`. Config: `chestCooldown`, `randomCooldown`, `storePoll`,
`storeHandPoll`, além das novas `espRange`, `collectRange`, `collectSkip`,
`storeKeep`; lista `FRUITS`.

| Pedido | Estado | Nota |
|---|---|---|
| Fruit ESP (nome/dist) | **Impl** | `setFruitESP` com nome + distância |
| Fruit ESP: distância máxima | **Impl** Auto | slider "ESP max distance" → `espRange` (0 = todas) |
| Fruit ESP: filtros por fruta/raridade | **Gap** | raridade não é exposta pelo jogo de forma simples |
| Coleta automática | **Impl** | `setCollect` via `nearestGroundFruit` |
| Coleta: distância máxima | **Impl** Auto | slider "Collect max distance" → `collectRange` |
| Coleta: lista de ignoradas | **Impl** Auto | textbox "Collect skip list" → `collectSkip` (prefixo, case-insensitive) |
| Coleta: seleção de frutas desejadas | **Parcial** | skip cobre "ignorar"; "só estas" não existe |
| Coleta: interromper com inventário cheio | **Gap** | sem leitura confiável de capacidade |
| Fruit Store (auto armazenar) | **Impl** | `setStore` |
| Fruit Store: lista de exceções | **Impl** Auto | textbox "Store keep list" → `storeKeep` |
| Fruit Store: condições/evitar importantes | **Parcial** | keep-list cobre "importantes" |
| Fruit Snipe | **Impl** | `setSnipe` + dropdown de fruta |
| Fruit Snipe: filtros de estoque / verificação | **Parcial** | usa `storePoll`; sem filtro por raridade |
| Auto Random Fruit | **Impl** | `setRandom` (gacha Zioles) |
| Auto Random Fruit: intervalo configurável | **Impl** | `randomCooldown` (sem controle dedicado) |
| Chest ESP | **Impl** | `setChestESP` |
| Chest ESP: filtro por tipo | **Gap** | casa `^Chest%d*$` e `SilverChest` |
| Chest Farm | **Impl** | `setChestFarm` (mais próximo primeiro, sem repetir) |
| Chest Farm: cooldown | **Impl** Auto | slider "Chest cooldown" → `chestCooldown` |

**Resumo Fruits:** a rodada deu configuração real a ESP/coleta/store/chest
(distância máxima, skip-list, keep-list, cooldown). O que resta são **features
que dependem de dado que o jogo não expõe de forma confiável** (raridade, capacidade
de inventário) ou variantes ("só coletar estas"), então ficam pendentes até haver
mecanismo — em vez de criar um controle que não muda nada.

---

## 5. RAIDS / EVENTS

Arquivo: `events.lua`. Config: `element`, além das novas `waveWait`, `startWait`,
`chipWait`; `raidLoc` por sea; `serverHop`.

| Pedido | Estado | Nota |
|---|---|---|
| Auto Raid: elemento / iniciar / skills / distância | **Impl** Auto | dropdown "Raid element"; skills/distância via Combat |
| Auto Raid: intervalo / condições / recursos | **Impl** Auto | sliders "Wave wait"/"Start wait"/"Chip wait" — eram `task.wait` fixos no loop |
| Eventos: seleção / filtros / prioridade | **Gap** | eventos fixos, sem seleção |
| Eventos: teleporte / intervalo de verificação | **Parcial** | teleporta; sem verificação automática contínua |
| Elite Hunter / Leviathan / Server Hop | **Impl** | controles existem (Elite/Leviathan sea-scoped) |
| Raid hint (próximo raid) | **Impl** Auto | botão "Next raid hint" → `M.raidHint()` (estava implementado e **nunca exposto**) |

**Resumo Events:** a rodada expôs o pacing do raid (os três `task.wait` fixos
viraram sliders reais, lidos pelo loop via `math.max(0, config[key])`) e ligou o
`raidHint()` que existia no código mas não tinha botão. Seleção de eventos e
verificação automática contínua continuam **Gap**: dependem de um sinal de evento
ativo que não é exposto de forma estável.

---

## 6. PLAYER

Arquivo: `player.lua`. Config: `noclip`, `walkWater`, `speedOn`,
`walkSpeed`, `jumpOn`, `jumpPower`, `ken`, `buso`, `antiAfk`, além das novas
`espRange`, `espName`.

| Pedido | Estado | Nota |
|---|---|---|
| ESP (dist/nome/filtros) | **Impl** Auto | sliders "ESP max distance" (`espRange`, 0=todos) + toggle "ESP show name" (`espName`) |
| WalkSpeed / JumpPower | **Impl** Auto | sliders existem e escrevem no config |
| Presets de movimento / restaurar | **Impl** Auto | desligar Speed/Jump restaura o valor-base capturado no spawn; `stop()` idem (antes era 16/50 chumbados) |
| NoClip / Walk on Water / Auto Ken / Buso / Anti-AFK | **Impl** | todos presentes |

**Resumo Player:** ESP ganhou distância máxima e alternância de nome; e o
"restaurar" virou **real** — `rememberBase()` guarda `WalkSpeed`/`JumpPower`
originais no `CharacterAdded` (e no init), então desligar a feature (ou `stop`)
devolve o valor do jogo em vez de um número fixo.

---

## 7. TELEPORT / SEA

Arquivo: `teleport.lua`. `config.speed` (agora com controle); `islands`,
`waypoints` (agora persistidos).

| Pedido | Estado | Nota |
|---|---|---|
| Velocidade / cancelar / destino inválido | **Impl** Auto | slider "Fly speed" → `config.speed` (50–1000); `M.cancel()` existe |
| Favoritos / waypoints personalizados | **Impl** Auto | 12 slots fixos "Go to waypoint #N" / "Clear waypoint #N" |
| Persistência de waypoints | **Impl** Auto | `Core.saveBlob/loadBlob` em `DepHub_BF_data_waypoints.json` (sobrevivem a rejoin) |
| Organização por categoria | **Impl** | seções ISLANDS/BOSSES/WAYPOINTS/FLIGHT |
| Pesquisa de destinos | **Gap** | sem busca na lista (dropdown do painel já navega) |
| Histórico de teleporte | **Gap** | não existe |
| Organização por Sea / infos | **Parcial** | listas por sea; sem info por destino |

**Resumo Teleport:** os waypoints eram só em memória e sem forma de apagar. Agora
são **dados persistidos** (blob próprio) com slots fixos de Go/Clear (o painel
renderiza uma vez; nada de re-registrar controles duplicados) e "Clear all". A
velocidade de voo deixou de ser constante cravada. Busca/histórico ficam pendentes
(mecanismo novo, não só config).

---

## 8. SHOP

Arquivo: `shop.lua`. `buy(action,arg)`; dealers por sea; auto-buy swords
(Rengoku/Oroshi/Shizu); config `legendaryPoll`.

| Pedido | Estado | Nota |
|---|---|---|
| Separar por categoria / filtros / busca | **Parcial** | seções SWORDS/GUNS/STYLES/ACCESSORIES; sem busca |
| Favoritos / compra individual | **Impl** | botões de compra por item |
| Compra automática / verif. dinheiro / requisitos | **Impl** Auto | slider "Legendary poll interval" → `legendaryPoll` (era 4s fixo); resultado tratado (0=dinheiro, 1=ok, 2=já tem) |
| Feedback de compra/falha | **Impl** | `notify` no `buy` |

---

## 9. EXTRAS

Arquivo: `extras.lua`. Race V4, V4 Trial, Race Upgrade/Reroll, Cake Prince,
Rip Indra; config `spawnWait`.

| Pedido | Estado | Nota |
|---|---|---|
| Config própria por sistema | **Impl** Auto | slider "Summon wait" → `spawnWait` (era 0.5 fixo) |
| Auto Cake Prince / Auto Rip Indra | **Impl** Auto | agora **desligam sozinhos** e avisam quando o boss não está na lista (antes ficavam presas ligadas sem fazer nada) |
| `farmBoss` reusa o farm | **Impl** | liga o Farm Boss com nome |

---

## 10. CONFIG

Arquivo: `core.lua`. `gatherConfig/applyConfig/saveNamedConfig/loadNamedConfig/
listConfigs/unload`, além de `deleteNamedConfig/renameNamedConfig/resetToDefaults/
resetModule` e os novos `saveBlob/loadBlob/deleteBlob`; prefixo `DepHub_BF_`;
`cfg_<name>.json`; `data_<name>.json`; `lastcfg.txt`.

| Pedido | Estado | Nota |
|---|---|---|
| Salvar/Carregar/Criar com nome/Listar | **Impl** Auto | existe |
| Excluir | **Impl** Auto | botão "Excluir configuração" → `deleteNamedConfig` (delfile) |
| Renomear | **Impl** Auto | botão "Renomear" → `renameNamedConfig` (lê/grava/apaga) |
| Restaurar padrões (tudo) | **Impl** Auto | botão "Restaurar padrões" → `resetToDefaults` (usa o `default` de cada `_def`) |
| Config por módulo / restaurar só um módulo | **Impl** Auto | dropdown "Módulo" + "Restaurar módulo" → `resetModule` via `moduleForPage` |
| Presets (Default/Safe/Fast/Custom) | **Gap** | não existe; ver nota abaixo |

> Os testes de Config rodam contra um **filesystem em memória** e um **codec JSON**
> adicionados ao harness — antes o `HttpService` era `{}` e não havia `writefile`,
> então nenhum Save/Load era testável.

**Nota sobre presets:** "Default" agora existe de fato (restaurar padrões). "Safe"
e "Fast" seriam combinações **nomeadas de valores** — implementáveis, mas só fazem
sentido depois que os módulos que eles juntam (Farm/PVP/Fruits) tiverem suas
configs fechadas; senão viram nomes bonitos sem efeito. Fica para depois dos
módulos, para não violar a §12.

---

## 11. EXPERIÊNCIA DO PAINEL

| Pedido | Estado | Nota |
|---|---|---|
| Seções organizadas / nomes claros | **Impl** | `groupFor`/`sectionFor` agrupam |
| Descrições úteis | **Impl** Auto | `renderDefinition` agora emite a `description` de cada controle como parágrafo (antes era capturada e descartada) |
| Pesquisa de features/config | **Impl** Auto | input "Search features" → `DemonUI:Search(q)` filtra abas por nome e combina com o filtro de sea |
| Status das automações | **Impl** Auto | seção "Status" na Home: parágrafo com o snapshot + botão "Refresh status" ao vivo |
| Abas organizadas | **Impl** | sidebar mostra só General + sea atual (v0.0.80) |

---

## Ordem de execução (estado)

1. **Farm** (§2): ✅ config de risco baixo exposta. Gaps de sistema pendentes.
2. **PVP** (§3): ✅ ignorados, parte/alcance do aimbot, ordem de skills (bug corrigido).
3. **Fruits** (§4): ✅ ESP/coleta/store/chest configurados; raridade/inventário pendentes.
4. **Config** (§10): ✅ excluir/renomear/reset-tudo/reset-módulo.
5. **Raids/Events** (§5): ✅ pacing + raid hint.
6. **Player** (§6): ✅ ESP range/nome + restore real de movimento.
7. **Teleport** (§7): ✅ fly speed + waypoints persistidos.
8. **Shop** (§8): ✅ legendário configurável.
9. **Extras** (§9): ✅ summon wait + auto-toggles com auto-off.
10. **Painel** (§11): ✅ descrições, busca de features, status de automações.

Cada etapa: suite verde + bundle + validate + bump + commit/push, declarando
**Impl / Auto / Game / Pendente** por funcionalidade. Gaps sem mecanismo real
(raridade de fruta, capacidade de inventário, bind de tecla do aimbot, histórico
de teleporte, presets Safe/Fast) ficam registrados com o motivo, não simulados.
