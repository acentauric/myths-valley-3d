"""Registra a origem dos GLBs de um lote do Tripo no ORIGEM.md de cada pasta.

Junta o arquivo do lote (tarefas e categorias), os prompts baixados do Studio
(`tripo_prompts_*.json`, opcional; ficam gravados no próprio lote) e a medida de cada
GLB (triângulos e tamanho), e escreve uma seção entre marcadores em
`assets/prototipo_3d/<pasta>/ORIGEM.md`. Rodar de novo só reescreve a seção.

Uso: python registrar_origem.py lote_2026-09-26.json [tripo_prompts.json]
"""
import json, os, re, struct, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
ASSETS = os.path.join(RAIZ, "assets", "prototipo_3d")
CAT = os.path.join(RAIZ, "scripts", "prototipo_3d", "catalogo_assets.gd")

TITULOS = {
    "arvores": "Árvores e vegetação geradas no Tripo",
    "construcoes": "Construções e peças geradas no Tripo",
    "casas": "Casas geradas no Tripo",
    "aderecos": "Adereços do arraial gerados no Tripo",
    "personagens": "Moradores e viajante gerados no Tripo",
    "itens": "Itens gerados no Tripo Studio",
}


def triangulos(caminho):
    with open(caminho, "rb") as f:
        f.read(12)
        n, _ = struct.unpack("<II", f.read(8))
        g = json.loads(f.read(n))
    total = 0
    for mesh in g.get("meshes", []):
        for prim in mesh.get("primitives", []):
            acc = g["accessors"][prim["indices"]] if "indices" in prim else g["accessors"][prim["attributes"]["POSITION"]]
            total += acc["count"] // 3
    return total


def resumo(prompt):
    texto = (prompt or "").split(" Stylized hand-painted")[0].strip()
    return texto.replace("|", "/")


def milhar(n):
    return f"{n:,}".replace(",", ".")


def main():
    lote_path = os.path.join(AQUI, sys.argv[1]) if not os.path.isabs(sys.argv[1]) else sys.argv[1]
    lote = json.load(open(lote_path, encoding="utf-8"))
    if len(sys.argv) > 2 and os.path.exists(sys.argv[2]):
        prompts = json.load(open(sys.argv[2], encoding="utf-8"))
        for chave, info in prompts.items():
            if chave in lote["tarefas"] and info.get("prompt") and info["prompt"] != "?":
                lote["tarefas"][chave]["prompt"] = info["prompt"]
        json.dump(lote, open(lote_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    caminhos = dict(re.findall(r'"([a-z_]+)":\s*\{"tripo":\s*"([^"]+)"', open(CAT, encoding="utf-8").read()))
    por_arquivo = {os.path.basename(p): p for p in caminhos.values()}
    pastas = {}
    for chave, tarefa in lote["tarefas"].items():
        rel = por_arquivo.get(f"{chave}_tripo.glb")
        if rel is None:
            print("sem entrada no catálogo:", chave)
            continue
        glb = os.path.join(ASSETS, rel)
        if not os.path.exists(glb):
            print("GLB ausente:", rel)
            continue
        cat = lote["categorias"][tarefa["categoria"]]
        pastas.setdefault(os.path.dirname(rel), []).append({
            "arquivo": os.path.basename(rel), "id": tarefa["id"], "prompt": resumo(tarefa.get("prompt", "")),
            "tri": triangulos(glb), "textura": cat["textura"].upper(), "mb": os.path.getsize(glb) / 1e6,
            "alvo": cat["poligonos"],
        })
    inicio, fim = "<!-- lote-2026-09-26:inicio -->", "<!-- lote-2026-09-26:fim -->"
    for pasta, linhas in sorted(pastas.items()):
        linhas.sort(key=lambda l: l["arquivo"])
        corpo = [inicio, "", "## Lote em Malha Smart de 26/09/2026", "",
                 "Geradas por texto no Tripo Studio (Modelo HD H3.1, textura 8K desligada, 55",
                 "créditos) e passadas pela Retopologia (Quad, Malha Smart, 40 créditos) com o",
                 "alvo de polígonos da categoria; exportadas em GLB com a textura da tabela.",
                 "Retopologia e exportação em lote por `tools/tripo/lote_studio.js`;",
                 "cópia para o projeto por `sincronizar_downloads.py` (originais em",
                 "`.assets-raw/tripo/`, fora do Git). Tarefas, categorias e prompts completos em",
                 "`tools/tripo/lote_2026-09-26.json`. Estas versões substituem as",
                 "reduzidas por `reduzir_glb.py` e os HD anteriores descritos acima; os arquivos",
                 "antigos continuam no histórico do Git.", "",
                 "| Arquivo | O que é (prompt) | Tarefa Tripo | Triângulos | Textura | MB |",
                 "| --- | --- | --- | ---: | --- | ---: |"]
        for l in linhas:
            corpo.append(f"| `{l['arquivo']}` | {l['prompt']} | `{l['id']}` | {milhar(l['tri'])} | {l['textura']} | {l['mb']:.1f} |")
        corpo += ["", "Uso comercial: plano Max no momento da geração (ver `assets/CREDITOS.md`).", "", fim]
        secao = "\n".join(corpo) + "\n"
        destino = os.path.join(ASSETS, pasta, "ORIGEM.md")
        texto = open(destino, encoding="utf-8").read() if os.path.exists(destino) else f"# {TITULOS.get(pasta, pasta)}\n"
        if inicio in texto:
            texto = re.sub(re.escape(inicio) + r".*?" + re.escape(fim) + r"\n?", lambda _: secao, texto, flags=re.S)
        else:
            texto = texto.rstrip("\n") + "\n\n" + secao
        open(destino, "w", encoding="utf-8").write(texto)
        print(f"{pasta:12s} {len(linhas):3d} peças → ORIGEM.md")


if __name__ == "__main__":
    main()
