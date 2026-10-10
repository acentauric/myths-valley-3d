# Fechar uma build

O passo a passo para levar a `develop` à `main` como uma build nova, com versão, tag e
publicação. Quem decide quando uma build fecha é o autor; até lá o trabalho fica na
`develop`, sem bateria obrigatória (AGENTS.md).

## A numeração

- **O build é o número que manda.** `build_numero` em `data/historico_3d.json` sobe 1 a
  cada build publicada, e é ele que o atualizador do jogo compara
  (`scripts/autoload/atualizacao.gd`). Nunca se repete nem desce.
- **A versão acompanha o build:** `v0.<build>.0`.
  - O número do meio é o build: a Build 11 é a `v0.11.0`.
  - Outro pacote do mesmo build, sem build novo, leva um rótulo depois do `+`:
    a 9B (Tripothon), o mesmo código da 9 exportado com o recurso `tripothon`, é a
    `v0.9.0+tripothon`. O rótulo não muda a ordem das versões. Nada de letra nos
    números (`v0.9B.0` não é versão válida: o GitHub e o git não ordenam), nem `-`
    (`v0.9.0-tripothon` quer dizer "antes da 0.9.0").
  - Correção publicada com zip novo é build novo: sobe o número do meio. O último
    número fica 0 enquanto o build for a chave do atualizador.
  - O `1.0.0` fica para o lançamento, por decisão do autor.
- **Na `develop` a versão leva `-dev`** (`0.11.0-dev`) e o `build_numero` continua o da
  última build publicada. Só no fechamento os dois andam juntos.
- **Tag só na `main`**, anotada, no commit que fecha a build: `git tag -a v0.11.0`. A
  `develop` nunca recebe tag.

Tags que já existem (retroativas, criadas em 10/10/2026): `v0.1.0` e `v0.2.0`
(reconstruídas: o histórico só começou a contar na Build 3) até `v0.10.0`, mais a
`v0.9.0+tripothon` da 9B. `git tag -l -n1` lista com a descrição.

## O passo a passo

1. **O autor joga e aprova a `develop`.**
2. **Bateria completa verde, com a árvore limpa:**
   `.\tools\prototipo_3d\testar.ps1 -Push` (painel em http://127.0.0.1:8765/).
3. **Versão e histórico**, num commit na `develop`:
   - `data/historico_3d.json`: `versao_atual` vira `0.<N>.0` (sem `-dev`) e
     `build_numero` vira `N`;
   - a entrada do dia no mesmo arquivo, em pt/en/es (a regra está no AGENTS.md, "Fechou
     a issue, atualize o plano"), com o título "Build N: ...";
   - `docs/projeto/CHANGELOG_3D.md`: a seção "Em desenvolvimento" vira "Build #N — data";
   - `tests/unidade/test_historico_em_linhas_longas.gd` cobra a data da entrada mais
     recente: acerte-a.
4. **Exportar** (pré-requisitos em [EXPORTAR_WINDOWS.md](../ferramentas/EXPORTAR_WINDOWS.md)):

   ```powershell
   & 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release 'Windows Desktop' build/windows/MythsValley3D.exe
   .\tools\prototipo_3d\conferir_icone_do_exe.ps1 -Exe build/windows/MythsValley3D.exe
   ```

   Zipe a pasta `build/windows` como `MythsValley3D-v0.<N>.0-build<N>-windows.zip`, dentro
   da pasta do projeto (`build/` está fora do Git). Confira `Get-PSDrive C` antes.
5. **Conferir e registrar o tamanho:**
   `.\tools\prototipo_3d\conferir_fechamento_de_build.ps1 -Zip <zip> -Registrar`.
   Ele avisa se quem tem a build anterior não vai se atualizar sozinho (o limite do zip
   que a build antiga leva embutido); nesse caso o site precisa dizer "baixe esta build
   pelo site uma vez". Commite o `data/atualizador_builds.json`.
6. **Levar à `main` e marcar:**

   ```powershell
   git switch main
   git merge --ff-only develop
   git tag -a v0.<N>.0 -m "Build <N>: <título da entrada do histórico>"
   git push origin main v0.<N>.0
   git switch develop
   ```

   A `main` só anda por fast-forward: se não der, a `develop` não partiu da `main` de
   agora e é preciso juntar antes (nunca force-push).
7. **Publicar no site** (repositório `myths-valley-APP`):
   - suba o zip para `public/downloads/` no servidor (ver o deploy da Hostinger);
   - `resources/data/builds.json`: a build atual passa para `historico`, e o topo ganha
     `versao`, `build`, `data`, e a plataforma `windows` ganha `arquivo`, `url`,
     `tamanho` e `sha256` (`Get-FileHash <zip> -Algorithm SHA256`);
   - commite e faça o deploy. O manifesto
     (`https://mythsvalley.app.br/api/jogo/atualizacao`) passa a oferecer a build nova.
8. **De volta à `develop`:** `versao_atual` vira `0.<N+1>.0-dev`, com o `build_numero` em
   `N`.

## A 9B e os pacotes

Um pacote a mais do mesmo build (outra edição, outro preset) ganha um rótulo depois do
`+` (`v0.<N>.0+<edicao>`), não sobe o `build_numero` e não entra na linha do
atualizador. A 9B (`v0.9.0+tripothon`, preset Windows Tripothon) é o exemplo: travada para a Tripothon, sem
atualização no jogo, com plataforma própria (`windows-b`) no `builds.json` do site.

## Para automatizar

O roteiro acima é o que um `tools/prototipo_3d/fechar_build.ps1` faria numa tacada:
conferir a árvore e a `develop`, rodar a bateria, subir versão e build, exportar,
zipar, conferir e registrar, juntar na `main`, criar e enviar a tag, e preparar o
`builds.json` do site com tamanho e SHA-256. A publicação no servidor fica com o autor.
