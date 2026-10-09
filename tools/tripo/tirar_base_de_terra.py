"""Tira do GLB o pedaço de terra em cima do qual o Tripo gerou a árvore (#141).

O ingazeiro (e as versões leve e de longe dele) vem de pé numa laje de terra de
uns 7 m por 5 m e meio metro de espessura, com fundo e bordas retas. Posta no
vale, ela aparece como uma peça pousada sobre o terreno: uma plataforma elevada
de beiras marcadas, que boia no declive e some no plano. O tronco e as raízes
ficam; vão embora os triângulos que tocam a faixa de baixo e se afastam do eixo
do tronco além da folga. Textura, UVs, materiais e escala não mudam, e nada é
regenerado no Tripo.

Uso (precisa de numpy; o cavaco precisa também de Pillow):
    python tools/tripo/tirar_base_de_terra.py <glb> --altura 7.5 --eixo=-1.35,0.05 [--aplicar]
    python tools/tripo/tirar_base_de_terra.py <glb> --altura 7.5 --cavaco 0.3 [--aplicar]

O CAVACO (`--cavaco ALTURA`): depois da laje sobrava, sob as raízes do ingazeiro, um resto
de terra laranja de beiras vivas, dentro do raio que a laje poupava para não cortar o pé
das raízes. O que o denuncia é a cor da terra (laranja saturado, que casca e raiz não
têm) em triângulos quase planos (normal com ao menos 60% na vertical) colados ao chão
(todos os vértices abaixo de ALTURA metros). Sai só isso; raiz, tronco e texturas ficam.
Os dois modos se somam: com `--eixo` e `--cavaco` juntos saem os dois conjuntos.

`--altura` é a do catálogo (`CatalogoAssets.PECAS`), que normaliza o modelo: as
medidas de `--eixo`, `--faixa` e `--raio` são em metros nessa escala, com o pé do
modelo em y = 0 e o eixo no chão (x, z) do espaço do modelo, no centro da caixa
que o GLB já trazia. Sem `--aplicar` só conta o que sairia; com ele, reescreve o
GLB no lugar, com os vértices que sobram compactados.
"""
import argparse
import colorsys
import io
import json
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import auditar_troncos as at  # noqa: E402


def partes(g, binario):
    """[(primitiva, {atributo: array}, índices (T, 3))] de cada primitiva do GLB."""
    saida = []
    for malha in g["meshes"]:
        for prim in malha["primitives"]:
            atributos = {nome: at.acessor(g, binario, i) for nome, i in prim["attributes"].items()}
            if "indices" in prim:
                ix = at.acessor(g, binario, prim["indices"]).reshape(-1).astype(np.int64)
            else:
                ix = np.arange(len(atributos["POSITION"]), dtype=np.int64)
            saida.append((prim, atributos, ix.reshape(-1, 3)))
    return saida


def cores_dos_triangulos(g, binario, prim, atributos, ix):
    """Cor base média (0-255, RGB) de cada triângulo, amostrada na textura do material nos
    três vértices. Precisa de Pillow. Sem textura de cor, devolve None."""
    from PIL import Image
    material = g["materials"][prim.get("material", 0)]
    amostra = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
    if amostra is None or "TEXCOORD_0" not in atributos:
        return None
    imagem = g["images"][g["textures"][amostra["index"]]["source"]]
    v = g["bufferViews"][imagem["bufferView"]]
    bruto = binario[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
    textura = np.asarray(Image.open(io.BytesIO(bruto)).convert("RGB"), dtype=np.float64)
    altura, largura = textura.shape[:2]
    uv = atributos["TEXCOORD_0"].astype(np.float64)[ix]  # (T, 3, 2)
    colunas = np.clip((uv[:, :, 0] * largura).astype(np.int64), 0, largura - 1)
    linhas = np.clip((uv[:, :, 1] * altura).astype(np.int64), 0, altura - 1)
    return textura[linhas, colunas].mean(axis=1)


def e_laranja(rgb):
    """Terra laranja: matiz de 0,04 a 0,12, saturação de 0,5 para cima, valor de 0,3 a 0,7."""
    h, s, v = colorsys.rgb_to_hsv(*(np.asarray(rgb) / 255.0))
    return 0.04 <= h <= 0.12 and s >= 0.5 and 0.3 <= v <= 0.7


def alinhar(dados, n=4):
    return dados + b"\0" * ((-len(dados)) % n)


def reescrever(g, binario, mantidos):
    """GLB novo com só os triângulos `mantidos` ((prim, bool[T]) por primitiva).
    Os vértices que sobram são compactados; imagens e materiais seguem iguais."""
    novo = json.loads(json.dumps(g))
    blob = b""
    vistas = []

    # As imagens embutidas passam como estão.
    for img in novo.get("images", []):
        v = g["bufferViews"][img["bufferView"]]
        pedaco = binario[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        vistas.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(pedaco)})
        img["bufferView"] = len(vistas) - 1
        blob += alinhar(pedaco)

    acessores = []
    prims = [p for m in novo["meshes"] for p in m["primitives"]]
    for prim, (_, atributos, ix), mantem in zip(prims, partes(g, binario), mantidos):
        triangulos = ix[mantem]
        usados = np.unique(triangulos)
        remap = np.full(len(atributos["POSITION"]), -1, dtype=np.int64)
        remap[usados] = np.arange(len(usados))
        for nome, indice in list(prim["attributes"].items()):
            antigo = g["accessors"][indice]
            dados = atributos[nome][usados]
            bruto = np.ascontiguousarray(dados).tobytes()
            vistas.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(bruto), "target": 34962})
            blob += alinhar(bruto)
            acessor = {k: v for k, v in antigo.items() if k not in ("bufferView", "byteOffset", "count", "min", "max", "sparse")}
            acessor.update({"bufferView": len(vistas) - 1, "count": int(len(usados))})
            if nome == "POSITION":
                acessor["min"] = [float(x) for x in dados.astype(np.float64).min(0)]
                acessor["max"] = [float(x) for x in dados.astype(np.float64).max(0)]
            acessores.append(acessor)
            prim["attributes"][nome] = len(acessores) - 1
        novos = remap[triangulos].reshape(-1)
        tipo = np.uint16 if len(usados) < 65535 else np.uint32
        bruto = novos.astype(tipo).tobytes()
        vistas.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(bruto), "target": 34963})
        blob += alinhar(bruto)
        acessores.append({"bufferView": len(vistas) - 1, "componentType": 5123 if tipo == np.uint16 else 5125,
                          "count": int(len(novos)), "type": "SCALAR"})
        prim["indices"] = len(acessores) - 1

    novo["accessors"] = acessores
    novo["bufferViews"] = vistas
    novo["buffers"] = [{"byteLength": len(blob)}]
    texto = json.dumps(novo, separators=(",", ":")).encode("utf-8")
    texto += b" " * ((-len(texto)) % 4)
    total = 12 + 8 + len(texto) + 8 + len(blob)
    return (struct.pack("<III", 0x46546C67, 2, total)
            + struct.pack("<II", len(texto), 0x4E4F534A) + texto
            + struct.pack("<II", len(blob), 0x004E4942) + blob)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("--altura", type=float, required=True)
    ap.add_argument("--eixo", default=None, help="x,z do eixo do tronco: liga a retirada da laje")
    ap.add_argument("--faixa", type=float, default=1.3, help="triângulo que toca abaixo desta altura (m)")
    ap.add_argument("--raio", type=float, default=0.95, help="e tem vértice mais longe que isto do eixo (m)")
    ap.add_argument("--cavaco", type=float, default=0.0, help="tira o cavaco de terra laranja colado ao chão, abaixo desta altura (m)")
    ap.add_argument("--aplicar", action="store_true")
    a = ap.parse_args()
    if a.eixo is None and a.cavaco <= 0.0:
        ap.error("diga --eixo (a laje), --cavaco (o cavaco) ou os dois")
    eixo = np.array([float(x) for x in (a.eixo or "0,0").split(",")])
    g, binario = at.ler_glb(a.glb)
    ps = partes(g, binario)
    # A normalização é a do catálogo: altura do GLB inteiro => a.altura.
    menor = min(float(p["POSITION"][:, 1].min()) for _, p, _ in ps)
    maior = max(float(p["POSITION"][:, 1].max()) for _, p, _ in ps)
    fator = a.altura / (maior - menor)
    mantidos = []
    tirados = total = 0
    area_do_cavaco = 0.0
    for prim, atributos, ix in ps:
        v = atributos["POSITION"].astype(np.float64)
        metros = (v - np.array([0.0, menor, 0.0])) * fator
        t = metros[ix]
        sai = np.zeros(len(ix), dtype=bool)
        if a.eixo is not None:
            longe = np.linalg.norm(t[:, :, [0, 2]] - eixo, axis=2).max(1)
            sai |= (t[:, :, 1].min(1) < a.faixa) & (longe > a.raio)
        if a.cavaco > 0.0:
            cores = cores_dos_triangulos(g, binario, prim, atributos, ix)
            if cores is not None:
                normal = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
                comprimento = np.linalg.norm(normal, axis=1) + 1e-12
                plano = np.abs(normal[:, 1]) / comprimento >= 0.6
                colado = t[:, :, 1].max(1) < a.cavaco
                laranja = np.array([e_laranja(c) for c in cores])
                cavaco = plano & colado & laranja
                area_do_cavaco += float((comprimento[cavaco] / 2.0).sum())
                sai |= cavaco
        mantidos.append(~sai)
        tirados += int(sai.sum())
        total += len(ix)
    print("%s: %d de %d triângulos saem (%.1f%%)" % (os.path.basename(a.glb), tirados, total, 100.0 * tirados / max(total, 1)))
    if a.cavaco > 0.0:
        print("  cavaco de terra laranja: %.2f m² (abaixo de %.2f m)" % (area_do_cavaco, a.cavaco))
    if not a.aplicar:
        return
    antes = os.path.getsize(a.glb)
    saida = reescrever(g, binario, mantidos)
    with open(a.glb, "wb") as f:
        f.write(saida)
    print("reescrito: %d -> %d bytes" % (antes, len(saida)))


if __name__ == "__main__":
    main()
