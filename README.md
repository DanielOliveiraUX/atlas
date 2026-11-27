# ATLAS: The Lost Frontier

Jogo cooperativo de exploração e captura de criaturas para Roblox (mobile primeiro, também PC; PT, EN, ES).

Os scripts vivem neste repositório e são sincronizados com o Roblox Studio pelo [Rojo](https://rojo.space). Mapas, modelos 3D e cenário ficam no arquivo do place, dentro do Studio.

## Configurar no Windows (uma vez)

1. Instale o **Rokit** (gerenciador de ferramentas): baixe o `rokit-*-windows-x86_64.zip` em <https://github.com/rojo-rbx/rokit/releases>, extraia e rode `rokit self-install` no terminal. Feche e abra o terminal.
2. Clone o repositório e instale o Rojo:
   ```
   git clone https://github.com/DanielOliveiraUX/atlas
   cd atlas
   rokit install
   ```
3. Instale o plugin do Rojo no Studio: `rojo plugin install`.
4. No Studio, abra o place do ATLAS e em **Game Settings → Security** ative **Enable Studio Access to API Services** (para testar o salvamento de dados).
5. Em **Game Settings → Localization**, defina o idioma de origem como **Português (Brasil)**.

## Trabalhar no dia a dia

1. No terminal, dentro da pasta: `rojo serve`
2. No Studio: aba **Plugins → Rojo → Connect**.
3. Aperte **Play**. Deve aparecer a tela "Carregando sua expedição…" e depois "Bem-vindo à ATLAS!". No Output: `[ATLAS] Servidor iniciado`.

## Estrutura

```
src/
  shared/        → ReplicatedStorage.Shared (servidor e cliente)
    Config/      valores de balanceamento (fadiga, criaturas, batalha, dificuldade, dados)
    Types/       tipos Luau
    Util/        TeamUtil, Localization
    UI/          Theme (mobile-first, escala por tela)
    Remotes.lua  todos os RemoteEvents/Functions
  server/        → ServerScriptService.Server
    Services/    regras do jogo (fonte de verdade)
    Data/        perfil padrão e migrações
  client/        → StarterPlayerScripts.Client
    Controllers/ lógica de interface e entrada
  localization/  UI.csv → LocalizationService (PT origem, EN, ES)
```

## Regras do código

- Toda regra de jogo roda no servidor. O cliente só pede; o servidor valida.
- Números de balanceamento ficam em `Config/`, nunca no meio da lógica.
- Todo texto visível usa chave de tradução em `UI.csv`.
- Mudou o formato do perfil? Suba `DataConfig.SchemaVersion` e crie a migração em `server/Data/Migrations.lua`.

## Andamento

- [x] Fase 1 — Fundação (estrutura, dados com trava de sessão, localização, base de UI mobile)
- [ ] Fase 2 — Tutorial, coleção e equipe
- [ ] Fase 3 — Pet no mundo
- [ ] Fase 4 — Batalha + fadiga
- [ ] Fase 5 — Captura
- [ ] Fase 6 — Expedição
- [ ] Fase 7 — Economia mínima
- [ ] Fase 8 — Multiplayer e balanceamento
- [ ] Fase 9 — Lançamento experimental
