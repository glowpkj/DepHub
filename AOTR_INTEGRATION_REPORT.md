# AOT:R — integração inicial para testes individuais

Data: 15/10/2026. Base inspecionada: `e6fffa4` do repositório glowpkj/DepHub.
Entrada analisada: `aotr_corrigido_v3.luau` (78.690 bytes). O script antigo não é executado nem baixado pelo DepHub.

## Estado da entrega

**Implementado** significa que há lógica conectada à interface. **Verificado estaticamente** significa inspeção, compilação e validação de referências. Os testes automatizados usam substitutos das APIs Roblox e não validam física, replicação, permissões de executor ou respostas do servidor. **Nenhum recurso foi testado em execução dentro do Roblox.**

Esta é uma integração inicial parcial. Ripper, os dois autofarms e a checagem de shadow ban não estão implementados; a interface os identifica como pendentes, sem toggles falsos.

| Recurso | Código entregue | Teste individual no Roblox / condição de sucesso |
|---|---|---|
| Titan ESP | Preservado; um Highlight próprio por modelo com Hitboxes, limpeza independente | Ativar, gerar outro Titan, desativar. Apenas Highlights DepHub devem desaparecer. Repetir dez vezes sem duplicação. |
| Nape Visible | Preservado; restaura transparência capturada | Alternar com Extend ligado e desligado; transparência deve voltar ao valor observado antes de ativar. |
| Nape Extend | Preservado; escala relativa ao tamanho original | Testar 0, 1 e 2; desativar restaura tamanho real, sem valores fixos antigos. Zero mantém a faixa anterior, mas torna a parte de tamanho zero. |
| Multiplicador | Validação 0–2, rejeita NaN e infinito | Mover slider, observar tamanho e confirmar restauração. A escala relativa existente foi preservada; o antigo usava cubo de 60 studs. |
| Extend Eren Weakpoint | Novo; amplia somente BasePart apontada por Marker.Adornee, dentro do Hit do próprio boss | Em raid, ativar e mudar fase/alvo. O alvo anterior deve voltar ao tamanho original. Desligar deve restaurar tudo. |
| Teleport to Refill | Preservado; agora cancela tween anterior, oferece cancelamento e cancela no respawn/unload | Encontrar GasTanks.Refill, iniciar, cancelar no caminho; repetir botão e reiniciar hub sem movimento residual. |
| Blade Refill | Novo; solicita GET("Blades", "Reload") com lâmina invisível, sets disponíveis e sem IFrames | Gastar lâmina com toggle ligado. Ver status, retorno visual e consumo real. Sem HUD não deve ocorrer erro fatal nem alteração fictícia do texto. Timeout de 30 s por episódio. |
| Auto Grab Escape | Parcial: escuta Buttons.ChildAdded e envia POST("Attacks", "Slash_Escape") | Sofrer grab e confirmar escape real. Criar outros botões para detectar falso positivo. A origem do evento ainda precisa de confirmação. Não destrói UI nem registra ataque extra. |
| Anti-Injury | Parcial: retira lesões locais da pasta, retém referências e restaura ao desligar | Sofrer lesão, ligar e desligar; confirmar pasta e efeito real. Não garante remoção da lesão no servidor. No respawn, não restaura lesões antigas no novo personagem. |
| Auto Retry | Novo; opção independente, uma solicitação por tela visível de recompensas | Finalizar missão, ativar, observar voto/reinício; desligar antes da próxima tela. STARTING e (0/0) bloqueiam solicitação. Textos atuais/localizados precisam ser confirmados. |
| Anti-AFK | Novo; uma conexão própria a Idled usa VirtualUser | Ativar, aguardar idle e conferir ausência de erros; desligar e confirmar desconexão. Depende de permissão de VirtualUser. Não desativa conexões de outros scripts. |
| Diagnóstico | PlaceId, GameId, Titans, HUD, refill, estados dos auxiliares e último erro | Abrir no lobby e missão; ausências devem aparecer como waiting/missing sem bloquear UI. |

## Pendências e prioridade recomendada

1. **P0: abertura e desligamento.** Testar loader no lobby e missão, reinício, fechamento real da UI, respawn e entrada tardia de Workspace.Titans. Recolher PlaceId/GameId e diagnóstico local se algo falhar. Fechar/destruir UI encerra o backend; apenas minimizar mantém recursos ativos.
2. **P1: base visual e movimento.** Testar ESP, Nape Visible/Extend combinados, Eren e cancelamento de teleporte. Confirmar hierarquia e restauração antes de automação.
3. **P1: assistência.** Testar recarga, escape, lesões, retry e idle separadamente. Confirmar contratos dos remotes e significado dos campos, sem assumir que uma solicitação enviada foi aceita.
4. **P2: Titan Ripper — pendente.** No anexo observa Parts `<nome>_Steel`, `_Thrust`, `_RIP`, amplia skill/napes, move hitboxes e congela animações. Precisa de controle de propriedade de cada alteração e restauração compatível com movimento do Titan; posições fixas antigas não são restauração correta. Nenhuma parte dessa rotina está ligada à UI nova.
5. **P2: Skill Autofarm — pendente.** No anexo chama S_Skills/Usage com IDs 108, 14, 23, 14 e depende do Ripper, ícones e cooldowns no Hotbar. Confirmar IDs/equipamento/cooldowns antes de integrar. Não basta repetir remotes para declarar farm pronto.
6. **P3: autofarm clássico — pendente.** No anexo usa BodyPosition, BV, BG, movimentação acima do alvo e Hitboxes/Register; também apaga Climbable e quase todo Unclimbable e desliga colisões sem restauração. Exige reimplementação do movimento e seleção de alvos, preservando mapa e física existente. Não foi transplantado.
7. **Check ShadowBan — pendente/inconclusivo.** O anexo faz GET(Data, Get), percorre chaves e conclui banimento por substring blacklist, ignorando dois nomes. Nil, chaves não string e valores não interpretados tornam a conclusão inválida. Não há diagnóstico confiável sem conhecer o contrato atual. Nenhum dado da conta é consultado ou enviado por esta integração.

## Arquitetura e arquivos

- `DepHub.lua`: versão 0.0.33; rotas AOTR por PlaceId 13379208636 e GameId 4658598196; fallback de nome anterior preservado. As rotas dos outros jogos foram mantidas.
- `src/games/aotr.lua`: fachada de estado e recursos visuais; carrega assistência usando SourceBaseURL da mesma revisão; valida números e gerencia tween, tarefa, Highlights e originais.
- `src/games/features/aotr/assistance.lua`: novo módulo com jobs próprios por recurso, referências renovadas por tick e cancelamento/limpeza ao desligar. Falha de download não impede as features visuais; ativação do auxiliar retorna false e registra erro.
- `.github/dephub-games.json`: nova entrada pelo universo, incluindo todos os módulos e marcador de atualização.
- `src/games/updates/4658598196.txt`: novo marcador.
- `src/version.txt`: sincronizado em 0.0.33.
- `tests/aotr_tests.luau`: novos testes comportamentais de roteamento sem nome, referências ausentes/não Titan, restauração, marcador, idempotência, lesões e cleanup.
- `tests/run_backend_tests.js`: inclui fontes e testes AOTR.
- `tests/headless_tests.luau`: expectativa da versão atualizada.
- `tests/validate_repo.js`: exige rastreamento de todos os módulos AOTR no manifesto.
- `AOTR_INTEGRATION_REPORT.md`: este relatório.

O frontend compacto do AOTR e a `library/compact.lua` foram removidos junto com toda a interface antiga; a UI nova consumirá `getgenv().__DEPHUB.Mode` e `getgenv().__DEPHUB.Backend`. Os módulos MM2/TSB e `src/core/updater.lua` foram preservados. O updater já usa GameId como ManifestId e a entrada nova atende esse contrato. `src/update-manifest.json` é gerado pelo workflow ao publicar em main; não foi preenchido manualmente com hashes fictícios.

## Correções e limitações do anexo

- Blade não é acessado diretamente em Frame sem checagem: procura recursivamente e valida o texto Sets; não falsifica número de recargas na interface.
- Evita pairs(nil) e o acesso a Hitboxes de Highlight, filtrando modelos e checando cada nível.
- Guarda tamanho/transparência reais em vez de restaurar constantes 15/9/11 ou 10/20/10. Eren e Nape compartilham composição no refresh para não sobrescrever estados independentes.
- Rejeita multiplicadores inválidos, NaN e infinito. Material e cor não são alterados.
- Não preserva referências únicas de Character, blade, HUD, pasta de lesões ou remotes entre respawns; procura novamente. Titans pode aparecer após inicialização.
- Jobs são cancelados ao desligar, evitando múltiplos loops. Uma chamada remota já enviada não pode ser desfeita no servidor; cancelar encerra a espera local. RemoteFunction bloqueada não gera novas tarefas a cada tick.
- Polling visual é de 1 s; auxiliares usam 0,5–1 s. Mudanças rápidas do Marker podem ser percebidas apenas no próximo refresh.
- Anti-Injury é uma adaptação reversível local, diferente da destruição permanente do anexo. Objetos já destruídos externamente podem não ser restauráveis; erro é diagnosticado.
- O anexo também tem UI Tekkit, arraste/RightShift, persistência em arquivo, ajuste de Atmosphere, avisos de recompensas e cópia de link Discord. Esses comportamentos não foram importados; não integram os recursos pedidos e alterariam UI/ambiente global.
- Nesta versão específica do anexo não foram encontradas URLs de webhook: o único link externo literal é Discord. Nenhum webhook, telemetria, envio de itens ou coleta de dados foi adicionado. Downloads adicionais limitam-se ao novo módulo do próprio DepHub pela base já existente.

## Caminhos a confirmar no jogo atual

- Workspace.Titans / `<Model>.Hitboxes.Hit.Nape`.
- Attack_Titan.Marker.Adornee e Hitboxes.Hit (Marker aceito como BillboardGui, Highlight ou SelectionBox).
- Workspace.Unclimbable ou Climbable / ancestral GasTanks / BasePart Refill.
- Character.Rig_<PlayerName>.LeftHand.Blade_1, Character.Injuries, atributo IFrames.
- PlayerGui.Interface.HUD.Main.Top / descendente Blade / Sets.
- PlayerGui.Interface.Buttons.ChildAdded: ainda não comprova que cada filho representa grab.
- PlayerGui.Interface.Rewards.Main.Info.Main.Buttons.Retry.Title e visibilidade dos ancestrais.
- ReplicatedStorage.Assets.Remotes.GET (RemoteFunction) e POST (RemoteEvent), com os argumentos indicados acima.
- VirtualUser disponível/permissões do ambiente.

IDs conferidos na página oficial Roblox: https://www.roblox.com/games/13379208636/Attack-on-Titan-Revolution e resultado oficial com universeId=4658598196. O teste automatizado cobre missão com PlaceId diferente e GameId conhecido; isso não substitui abrir uma missão real.

## Validação realizada

- Validação do repositório e referências: passou em v0.0.32.
- Compilação Luau dos 77 arquivos Lua em src, library, diagnostics e loader: passou.
- Backend/headless/ciclo de vida: 296 verificações passaram, incluindo AOTR e regressões existentes.
- Biblioteca: 71 verificações passaram.
- Revisão do diff e espaços: sem erros. Biblioteca e implementação de outros jogos não foram alteradas.
- Roblox: **não executado**. Visual da UI, aceitação de remotes, efeitos de gameplay, executor e replicação permanecem sem teste.

## Como testar a revisão publicada

Ao testar uma branch, passar seu nome como argumento do loader para que a UI e a assistência venham da mesma revisão:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/codex/aotr-integration/DepHub.lua"))("codex/aotr-integration")
```

Não executar o anexo Tekkit em paralelo. Começar com todos os recursos desligados, ativar um por vez e registrar nome do toggle, lobby/missão, diagnóstico e erro. Depois testar as combinações visuais, repetição de toggles, respawn e reinicialização.
