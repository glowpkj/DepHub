# DepHub

Framework client-side Luau com loader, backends separados por jogo e biblioteca própria de UI.

## Estrutura

- `DepHub.lua`: seleção por PlaceId/GameId, carregamento, estado da sessão e cleanup.
- `src/core`: serviços compartilhados, movimento com owner/prioridade, dashboard e updater.
- `src/games`: APIs dos backends; `features/<jogo>` contém as implementações específicas.
- `library`: componentes, janela com HOME fixa, adaptadores de conteúdo e biblioteca compacta.
- `.github/dephub-games.json`: arquivos que participam do hash de atualização de cada jogo.
- `diagnostics/compatibility.lua`: diagnóstico somente de leitura das dependências já usadas pelos backends.

## Validação

```text
node tests/validate_repo.js
node tests/run_backend_tests.js /caminho/para/luau
node tests/run_library_tests.js /caminho/para/luau
luau-compile --null DepHub.lua <arquivos .lua em src e library>
```

Os testes usam simuladores de APIs Roblox. Eles verificam comportamento local e cleanup, mas não comprovam remotes, física, replicação, timings de ataque ou compatibilidade com Madium.

## Teste no jogo

1. Execute o loader e habilite uma feature de cada vez.
2. Desabilite e habilite novamente; confira se há workers ou interfaces duplicados.
3. Morra, reapareça e repita o teste. Teste também entrada/saída de jogadores e objetos.
4. Reexecute o loader com a sessão saudável e depois com a UI destruída.
5. Se uma feature falhar, execute `diagnostics/compatibility.lua` e envie o JSON junto com o erro e a ação que falhou.

O diagnóstico não chama remotes, não ativa automações e não verifica se o servidor aceita os argumentos existentes. Dependência ausente pode significar mudança no jogo, carregamento incompleto ou contexto incorreto; não se deve inventar uma substituição.

## Versões e origem

A versão global fica em `DepHub.lua` e `src/version.txt`. Backends versionados têm notas em `src/games/updates`. O workflow gera `src/update-manifest.json` com hashes dos arquivos monitorados.

Para testar uma revisão isolada, o launcher pode definir temporariamente `getgenv().__DEPHUB_SOURCE_REF` com um SHA ou branch. Todos os carregadores internos seguem a origem selecionada. O comportamento padrão continua sendo `main`. Use SHA para um teste consistente enquanto o repositório recebe atualizações.

## Alterações em 0.0.29

- Recuperação de sessão com UI/backend destruídos; proteção contra inicializações concorrentes e updater antigo.
- Fallback HTTP sem lacunas na lista de funções, cache por origem e updater com Start idempotente.
- Universal: cancelamento do worker de chat, cleanup por jogador/Character e atualização de ESP a 10 Hz.
- Noob Piece: dependências com timeout, rollback de inicialização e cleanup idempotente.
- MM2: substituição dos listeners de Character/Backpack e agrupamento de pedidos de rescan.
- TSB: recuperação de componentes do oponente por eventos, cleanup na morte local e liberação pareada do contra-ataque.
- RT3: rebind quando DropFolder é substituída e descarte de tarefas de coleta antigas.
- UI compacta: atualização quando a câmera muda e fechamento sem coroutine esperando Tween.Completed.
- Arquivos faltantes adicionados ao controle de atualização; testes e diagnóstico atualizados.

Não foram substituídos protocolos dos jogos nem recalibrados alcance/timings de combate. AutoFarm e InstantCook do RT3 ainda contêm movimentos diretos legados: teste individualmente antes de combinar automações. A integração completa deles com ownership de movimento exige teste real e uma tarefa dedicada.

## TSB em 0.0.30 (backend 0.0.10)

A interface do TSB tem apenas Auto Block. Ele liga os detectores existentes de M1, dash e skills; não dispara contra-ataques. O block não é mais cancelado por clique/estado de M1 local e é renovado enquanto ataques conhecidos permanecem ativos no alcance. M1 usa o alcance configurado sem a caixa adicional que reduzia o limite efetivo à metade. Os tempos e IDs existentes foram mantidos.

Uma ação de ContextActionService com prioridade acima de High retém MouseButton1 enquanto o block está ativo. O M1 já segurado recebe LeftClickRelease antes do pedido de F. Depois da ameaça e do hold existente, o clique passa novamente; nenhum ataque é enfileirado para disparar sozinho. A ação é removida ao desligar/destruir o backend. Se ela não puder ser instalada, a ativação falha.

Limites: KeyPress não é confirmação de defesa pelo servidor. ContextActionService não garante travar scripts de input que ignorem o processamento do Roblox. A trava cobre MouseButton1; teclas de skills, gamepad e botões mobile ainda não foram validados. O catálogo não informa quais skills são unblockable nem o fim exato de cada hitbox; término de animação mais hold existente é somente uma aproximação. Não há garantia de 100% de bloqueio ou de uma janela perfeitamente segura.

Teste em sessão controlada: habilite o único toggle, segure M1 enquanto outro jogador aplica a sequência completa; confirme que não há ataque local durante a defesa e que um novo clique funciona ao terminar. Repita com duas ameaças, dash, morte/respawn, reexecução e toggle desligado. Se M1 ainda sair durante o block, reporte o ataque e o input: isso exige observar o caminho real do jogo, sem inventar hooks ou remotes.

API oficial de input: https://create.roblox.com/docs/reference/engine/classes/ContextActionService
