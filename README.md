# DepHub

Framework client-side Luau com loader e backends separados por jogo. A interface (frontend/library) é fornecida em um módulo próprio e não faz mais parte deste repositório.

## Estrutura

- `DepHub.lua`: seleção por PlaceId/GameId, carregamento, estado da sessão e cleanup. **Não carrega frontend.**
- `src/core`: serviços compartilhados, movimento com owner/prioridade, dashboard e updater.
- `src/games`: APIs dos backends; `features/<jogo>` contém as implementações específicas.
- `.github/dephub-games.json`: arquivos que participam do hash de atualização de cada jogo.
- `diagnostics/compatibility.lua`: diagnóstico somente de leitura das dependências já usadas pelos backends.

O loader publica o modo e o backend ativo para a interface consumir:

```lua
getgenv().__DEPHUB.Mode    -- "AOTR" | "TSB" | "MM2" | "NoobPiece" | "BloxFruits" | "RT3" | "Universal"
getgenv().__DEPHUB.Backend -- a tabela de estado do backend da sessão
```

## Jogos suportados

| Jogo | PlaceId / GameId | Mode |
| --- | --- | --- |
| Attack on Titan Revolution | 13379208636 / 4658598196 | AOTR |
| The Strongest Battlegrounds | 10449761463 / 3808081382 | TSB |
| Murder Mystery 2 | 142823291 / 66654135 | MM2 |
| Noob Piece | 84822469255086 | NoobPiece |
| Blox Fruits | 994732206 / 85211729168715 | BloxFruits |
| Restaurant Tycoon 3 | 119048529960596 | RT3 |
| (fallback) | qualquer outro | Universal |

## Validação

```text
node tests/validate_repo.js
node tests/run_backend_tests.js /caminho/para/luau
luau-compile --null DepHub.lua <arquivos .lua em src e diagnostics>
```

Os testes usam simuladores de APIs Roblox. Eles verificam comportamento local e cleanup, mas não comprovam remotes, física, replicação, timings de ataque ou compatibilidade com Madium.

## Teste no jogo

1. Execute o loader e habilite uma feature de cada vez.
2. Desabilite e habilite novamente; confira se há workers ou interfaces duplicados.
3. Morra, reapareça e repita o teste. Teste também entrada/saída de jogadores e objetos.
4. Reexecute o loader com a sessão saudável e depois com o backend destruído.
5. Se uma feature falhar, execute `diagnostics/compatibility.lua` e envie o JSON junto com o erro e a ação que falhou.

O diagnóstico não chama remotes, não ativa automações e não verifica se o servidor aceita os argumentos existentes. Dependência ausente pode significar mudança no jogo, carregamento incompleto ou contexto incorreto; não se deve inventar uma substituição.

## Versões e origem

A versão global fica em `DepHub.lua` e `src/version.txt`. Backends versionados têm notas em `src/games/updates`. O workflow gera `src/update-manifest.json` com hashes dos arquivos monitorados.

Para testar uma revisão isolada, o launcher pode definir temporariamente `getgenv().__DEPHUB_SOURCE_REF` com um SHA ou branch. Todos os carregadores internos seguem a origem selecionada. O comportamento padrão continua sendo `main`. Use SHA para um teste consistente enquanto o repositório recebe atualizações.

## Alterações em 0.0.33

- Removidos Volleyball Legends e Violence District (backends, features, notas, rotas, testes e diagnóstico).
- Removida toda a biblioteca de interface (`library/`) e todos os `frontend.lua` dos jogos. O loader não carrega mais frontend.
- `DepHub.lua`: cleanup sem chaves órfãs, `sessionHealthy` restrito aos backends vivos, `Mode`/`Backend` publicados para a nova biblioteca.
- Testes e validação ajustados ao loader sem frontend.

## Backends

Cada backend expõe uma API de estado (toggles, valores, ações e `Destroy`). A interface nova deve chamar esses métodos; os backends não criam `ScreenGui`/Frame próprios.

- **Universal**: movimento, ESP, fullbright, aim, chat loop, teleporte, server hop e ferramentas externas.
- **Blox Fruits**: ESP, frutas, observação, unbreakable, camera shake, dash, flashstep, water walking, team e VFX de fruta.
- **TSB**: Auto Block (detectores de M1, dash e skills) com guard de input; nenhum contra-ataque automático.
- **MM2**: role/round tracker, ESP, coin farm, teleporte e GunDrop.
- **Noob Piece**: chest/PNC ESP, autochest, autoattack, autofarm, autoteam, gacha, autoquest e tracker de ilha.
- **RT3**: runtime com scheduler, health monitor, dashboard, anti-AFK e features de automação.
- **AOT:R**: Titan ESP, Nape Visible/Extend, multiplicador, Eren weakpoint, refill, escape, anti-injury, retry e anti-AFK.

### Limites conhecidos

AutoFarm e InstantCook do RT3 ainda contêm movimentos diretos legados: teste individualmente antes de combinar automações. A integração completa deles com ownership de movimento exige teste real e uma tarefa dedicada. Nenhum backend foi testado dentro do Roblox nesta revisão; visual, remotes, física e replicação permanecem sem teste.
