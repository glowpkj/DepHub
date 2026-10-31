# Contribuindo com o DepHub

O contrato completo do repositório está em **[`DEPHUB-CONVENCOES.txt`](DEPHUB-CONVENCOES.txt)**.
Leia antes de programar, corrigir um jogo ou adicionar um jogo novo.

Resumo do que esse arquivo diz:

- **Organize por categoria, nunca por nome de jogo.** As abas seguem a finalidade
  (`Visual`, `Combat`, `Farm`, `Movement`, `Player`, `World`, `Misc`, `Settings`),
  iguais em todo jogo. Cada jogo cria só as categorias que usa.
- **Frontend e backend refletem a mesma organização.** Cada recurso mora em uma
  categoria lógica, sem duplicação.
- **O shell compartilhado é dono de toda a GUI.** O backend nunca cria GUI crua;
  usa a API (`UI:CreateCategory/CreateTab`, `tab:CreateSection(titulo, coluna)`,
  `section:CreateToggle/Slider/Dropdown/...`).
- **`CreateSection` só aceita `"Left"` ou `"Right"`.** Qualquer outro valor
  descarta a seção e deixa a aba **vazia** — bug real, ver seção 8 do txt.
- **Todo controle muda comportamento de verdade**, e todo recurso ligado desliga
  limpo no `Destroy()`.
- **Nunca simule funcionamento.** Se não dá para implementar confiável, explique
  por quê em vez de entregar um stub que finge funcionar.

Antes de dar qualquer coisa como pronta, rode o gate inteiro
(`run_backend_tests.js`, `validate_repo.js`, `bundle.js`, `verify_bundle.js`) —
o checklist completo está na seção 9 do `DEPHUB-CONVENCOES.txt`.
