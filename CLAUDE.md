# ATLAS — instruções para o Claude

Jogo Roblox em Luau, sincronizado com o Studio via Rojo (`default.project.json`).
Documentos de design: GDD v2.2 + "decisoes-atlas.md" no Project "roblox" do Claude. Onde conflitarem, valem as decisões.

## Onde cada coisa fica
- Scripts: só neste repositório (`src/`). Não criar scripts direto no Studio — o Rojo sobrescreve.
- Modelos 3D, mapas, cenário: no Studio (Workspace / ReplicatedStorage.Assets), fora do Rojo.
- Balanceamento: `src/shared/Config/`. Textos: `src/localization/UI.csv` (colunas Key,Source,Context,Example,en,es; Source em PT-BR).

## Convenções
- Serviços (servidor) e controllers (cliente) são ModuleScripts com `:Init()` e `:Start()` opcionais; registrar na lista ORDER do `init.*.lua`.
- Servidor é a fonte de verdade. Validar todo Remote (propriedade, existência, fadiga, limites).
- Equipe: `ActiveTeam` é a verdade; StorageState é derivado (`Util/TeamUtil`). Slot vazio = `false`.
- Fadiga: `FatigueUntil` (os.time). Cliente só mostra contagem; nunca libera o pet.
- Mudou o perfil: subir `DataConfig.SchemaVersion` + migração em `server/Data/Migrations.lua`; campo novo também em `DefaultProfile`.
- Tabs para indentação. Comentários em português.
- Escopo: vertical slice simples primeiro; competitivo/PvP é pós-MVP.
