# Publicando o DepHub

O botão é o **`publish.bat`** (duplo-clique) ou o **`publish.ps1`** (linha de
comando). Os dois fazem a mesma coisa: rodam o gate local inteiro e empurram
tudo pro `glowpkj/DepHub` na branch `main`.

## O que ele faz, em ordem

1. Acha o **Git** e o **Luau CLI** (portáteis em `C:\Users\<você>\tools`, depois
   o PATH).
2. Roda o **gate local**:
   - `node tests/validate_repo.js`
   - `node tests/run_backend_tests.js <luau>` (testes de backend/headless)
   - `luau-compile --null DepHub.lua <todas as fontes>`
3. **Regenera** `src/update-manifest.json` com o mesmo algoritmo do CI.
4. Faz `git add -A`, commit, e **push** pra `origin/main`.

Se qualquer etapa falhar, ele para e **não publica nada**.

## Login do GitHub (só na primeira vez)

A autenticação é feita pelo **Git Credential Manager**, usando a sua **conta do
GitHub** — nada de token na mão:

1. Na primeira vez que o script for empurrar, o GCM **abre uma janela no
   navegador**.
2. Você clica em **"Authorize"** / entra na conta.
3. Pronto. A credencial fica salva (criptografada com DPAPI) e os próximos
   pushes são automáticos — não pede mais nada.

Se a janela não abrir (raro), rode de novo: `publish.ps1` ou `publish.bat`.

## Uso

```
:: Duplo-clique
publish.bat

:: Linha de comando
powershell -ExecutionPolicy Bypass -File publish.ps1
powershell -ExecutionPolicy Bypass -File publish.ps1 -Message "feat: blox fruits autofarm"
powershell -ExecutionPolicy Bypass -File publish.ps1 -DryRun     :: só o gate, não commita
powershell -ExecutionPolicy Bypass -File publish.ps1 -NoPush     :: commita, não empurra
powershell -ExecutionPolicy Bypass -File publish.ps1 -SkipTests  :: pula o gate (use com cautela)
```

## Token (opcional, só pra uso sem navegador/headless)

Se algum dia precisar publicar sem login interativo (ex: script automático),
aí sim um **Personal Access Token** funciona. Basta uma das duas:

- `setx DEPHUB_GIT_TOKEN ghp_seuTokenAqui` (escopo `repo`), ou
- gravar o token em `.publish-token` na raiz do repo (é **gitignored**).

O script detecta o token e o usa; sem token, cai no login normal pelo GCM.

## CI no GitHub

Depois que o push chega na `main`, o GitHub Actions assume sozinho:

- `.github/workflows/regression.yml` — valida + compila + roda os testes
- `.github/workflows/update-manifest.yml` — regenera o manifest com o commit
  real e o histórico recente, e commita de volta

Ou seja: seu script faz o gate e o push; o CI confirma e finaliza o manifest
com metadata de commit de verdade. Depois de um push, um `git pull` traz o
manifest finalizado pelo CI.

## Ferramentas portáteis

Não há Git nem Luau instalados no sistema — o script usa cópias portáteis,
já no PATH do usuário:

- Git (MinGit): `C:\Users\<você>\tools\mingit\cmd\git.exe`
- Git Credential Manager: `C:\Users\<você>\tools\gcm\`
- Luau: `C:\Users\<você>\tools\luau-win\` (`luau.exe`, `luau-compile.exe`)
- Node.js: instalado no sistema (v24)

Se mover essas pastas, ajuste os caminhos no começo do `publish.ps1` (bloco
`Tool discovery`).
