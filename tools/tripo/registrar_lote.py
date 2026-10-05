"""Registra a origem de um lote do Tripo Studio produzido por lote_producao.js.

Lê o arquivo do lote (`tarefas`: {chave: {pasta, faces, tex, rig, prompt}}) e, quando
passado, o estado da produção salvo da página (`__mv.prod`, com tarefa, projeto,
exportação, rig e animações de cada chave), grava esses dados de volta no lote e escreve
uma seção entre marcadores no ORIGEM.md de cada pasta com os GLBs que já estão no
projeto: tarefa, triângulos, textura, rig, clipes, tamanho e SHA-256. Rodar de novo só
reescreve a seção.

Uso: python registrar_lote.py lote.json [estado_producao.json] [--exceto chave,chave]
  --exceto  chaves que já têm registro próprio no ORIGEM.md (não entram na seção do lote).
"""
import hashlib, json, os, re, struct, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
ASSETS = os.path.join(RAIZ, "assets", "prototipo_3d")

TITULOS = {
    "arvores": "Árvores e vegetação geradas no Tripo",
    "construcoes": "Construções e peças geradas no Tripo",
    "aderecos": "Adereços do arraial gerados no Tripo",
    "personagens": "Moradores e viajante gerados no Tripo",
    "animais": "Bichos do vale gerados no Tripo",
    "peixes": "Peixes e raias gerados no Tripo",
}
ASSUNTO = {
    "arvores": "a flora que faltava ao paisagismo por zonas",
    "construcoes": "as casas e construções novas do arraial",
    "aderecos": "os varais e o que falta aos quintais",
    "personagens": "os moradores sem fala e quem faltava no arraial",
    "animais": "os bichos de quintal e as onças da mata",
    "peixes": "os cardumes do mar, das pedras e do rio",
}


def gltf(caminho):
    with open(caminho, "rb") as f:
        f.read(12)
        n, _ = struct.unpack("<II", f.read(8))
        return json.loads(f.read(n))


def triangulos(g):
    total = 0
    for mesh in g.get("meshes", []):
        for prim in mesh.get("primitives", []):
            acc = g["accessors"][prim["indices"]] if "indices" in prim else g["accessors"][prim["attributes"]["POSITION"]]
            total += acc["count"] // 3
    return total


def sha(caminho):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def milhar(n):
    return f"{n:,}".replace(",", ".")


RIGS = {"biped": "Mixamo", "quadruped": "quadrúpede", "avian": "ave", "aquatic": "aquático", "serpentine": "serpente"}
# Título e parágrafo de cada lote da noite de 05/10/2026, pelo fim do nome do arquivo.
LOTES = {
    "level_design": "Level design de 05/10/2026",
    "fauna_itens": "Fauna de 05/10/2026, segunda leva",
    "moradores": "Moradores de 05/10/2026: ofícios e casas a mais",
    "paisagismo": "Paisagismo de 05/10/2026, segunda leva",
    "lod": "Versões leves e de longe de 05/10/2026",
}


def main():
    args = sys.argv[1:]
    exceto = set()
    if "--exceto" in args:
        i = args.index("--exceto")
        exceto = {c.strip() for c in (args[i + 1] if i + 1 < len(args) else "").split(",") if c.strip()}
        del args[i:i + 2]
    sys.argv = [sys.argv[0]] + args
    lote_path = sys.argv[1] if os.path.isabs(sys.argv[1]) else os.path.join(AQUI, sys.argv[1])
    lote = json.load(open(lote_path, encoding="utf-8"))
    if len(sys.argv) > 2:
        estado = json.load(open(sys.argv[2], encoding="utf-8"))
        if isinstance(estado, str):
            estado = json.loads(estado)
        for chave, st in estado.items():
            t = lote["tarefas"].get(chave)
            if t is None:
                continue
            t["tarefa"], t["projeto"], t["exportacao"] = st.get("task"), st.get("pid"), st.get("exportId")
            if st.get("rigDone"):
                t["rig_feito"] = st.get("rigType")
                t["animacoes"] = sorted(p.split(":")[-1] for p, v in (st.get("anims") or {}).items() if v == "ok")
            elif st.get("rigFalhou"):
                t["rig_feito"] = None
    marcador = "lote-" + os.path.splitext(os.path.basename(lote_path))[0].replace("lote_", "")
    inicio, fim = f"<!-- {marcador}:inicio -->", f"<!-- {marcador}:fim -->"
    pastas = {}
    for chave, t in lote["tarefas"].items():
        glb = os.path.join(ASSETS, t["pasta"], f"{chave}_tripo.glb")
        if chave in exceto or not os.path.exists(glb):
            continue
        g = gltf(glb)
        t["sha256"] = sha(glb)
        clipes = len(g.get("animations", []))
        rig = t.get("rig_feito")
        rig_txt = "—" if not rig else RIGS.get(rig, rig) + (f", {clipes} clipe" + ("s" if clipes != 1 else "") if clipes else "")
        pastas.setdefault(t["pasta"], []).append({
            "arquivo": f"{chave}_tripo.glb", "prompt": t["prompt"].split(" Stylized hand-painted")[0].strip().replace("|", "/"),
            "tarefa": t.get("tarefa") or t.get("projeto") or "?", "tri": triangulos(g), "tex": "2K" if int(t.get("tex", 1024)) >= 2048 else "1K",
            "rig": rig_txt, "mb": os.path.getsize(glb) / 1e6, "sha": t["sha256"], "faces": t.get("faces"),
        })
    json.dump(lote, open(lote_path, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
    for pasta, linhas in sorted(pastas.items()):
        linhas.sort(key=lambda l: l["arquivo"])
        alvos = sorted({l["faces"] for l in linhas if l["faces"]})
        alvo = milhar(alvos[0]) if len(alvos) == 1 else f"{milhar(alvos[0])} a {milhar(alvos[-1])}"
        sufixo = os.path.splitext(os.path.basename(lote_path))[0].split("2026-10-05_")[-1]
        titulo = LOTES.get(sufixo, "Lote de 05/10/2026")
        if sufixo == "lod":
            paragrafo = [
                "Refeitas pela Retopologia (Quad, Malha Smart, 40 créditos) sobre o projeto",
                "original de cada árvore no Tripo Studio, com alvo de " + alvo + " faces: a mesma",
                "forma e a mesma textura da árvore de perto, só a malha muda. As `*_leve` vão",
                "para a mata e os pomares (a árvore de mata pesava de 12 a 16 mil faces); as",
                "`*_longe` são o desenho que entra onde a árvore sai, ao longe. Na coluna da",
                "tarefa vai o projeto de origem. Pela ponte do Playwright MCP com",
                "`tools/tripo/lote_producao.js`.",
            ]
        else:
            paragrafo = [
                "Gerados por texto no Tripo Studio em 05/10/2026 (Modelo HD H3.1, textura 8K",
                "desligada, 55 créditos) e passados pela Retopologia (Quad, Malha Smart, 40",
                "créditos) com alvo de " + alvo + " faces. Os que têm rig passaram pelo",
                "pre_rig_check e pelo rig do Studio (20 créditos): Mixamo para gente e o do",
                "tipo do bicho para os outros (quadrúpede, ave, aquático, serpente), com as",
                "animações prontas do Studio aplicadas uma de cada vez e exportadas juntas no",
                "GLB. Tudo pela ponte do Playwright MCP com a extensão do Chrome, com",
                "`tools/tripo/lote_studio.js` e `tools/tripo/lote_producao.js`.",
            ]
        corpo = [inicio, "", f"## {titulo}: {ASSUNTO.get(pasta, pasta)}", ""] + paragrafo + [
                 "Cópia para o projeto por `sincronizar_downloads.py` (originais em",
                 "`.assets-raw/tripo/`, fora do Git). Tarefas, projetos e prompts completos em",
                 f"`tools/tripo/{os.path.basename(lote_path)}`. Uso comercial: plano pago no",
                 "momento da geração (ver `assets/CREDITOS.md`).", "",
                 "| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | Rig | MB |",
                 "| --- | --- | --- | ---: | --- | --- | ---: |"]
        for l in linhas:
            mb = f"{l['mb']:.1f}".replace(".", ",")
            corpo.append(f"| `{l['arquivo']}` | {l['prompt']} | `{l['tarefa']}` | {milhar(l['tri'])} | {l['tex']} | {l['rig']} | {mb} |")
        corpo += ["", "SHA-256 de cada GLB no arquivo do lote (`sha256`).", "", fim]
        secao = "\n".join(corpo) + "\n"
        destino = os.path.join(ASSETS, pasta, "ORIGEM.md")
        texto = open(destino, encoding="utf-8").read() if os.path.exists(destino) else f"# {TITULOS.get(pasta, pasta)}\n"
        if inicio in texto:
            texto = re.sub(re.escape(inicio) + r".*?" + re.escape(fim) + r"\n?", lambda _: secao, texto, flags=re.S)
        else:
            texto = texto.rstrip("\n") + "\n\n" + secao
        open(destino, "w", encoding="utf-8", newline="\n").write(texto)
        print(f"{pasta:12s} {len(linhas):3d} peças → ORIGEM.md")


if __name__ == "__main__":
    main()
