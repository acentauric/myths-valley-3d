"""MEDE AS CORES E AS PROPORÇÕES DAS CONSTRUÇÕES para a casa de longe
(scripts/prototipo_3d/pecas_distantes.gd, tabela CASAS).

    python tools/prototipo_3d/medir_cores_das_casas.py            # todas as construções
    python tools/prototipo_3d/medir_cores_das_casas.py casa_taipa igreja

Lê cada GLB de assets/prototipo_3d/construcoes/ e casas/ (só o arquivo, sem o Godot) e
imprime uma linha pronta para colar em CASAS:

  - parede: a média da textura (em luz linear, ponderada pela área do triângulo) nas faces
    de parede, as verticais entre 8% e 70% da altura;
  - telha: o mesmo nas faces de telhado, as de normal para cima acima de 35% da altura;
  - beiral: a altura em que o telhado começa (o 8º percentil da altura dos centros das faces
    de telhado), em fração da altura total;
  - corpo_x, corpo_z: onde ficam as paredes (os vértices de 12% a 50% da altura, do percentil 2
    ao 98), em fração da caixa.

A média da textura diz a cor do que a casa É a 150 u, e é isso o que a casa de longe
mostra; porta e janela, que são de outra cor, pesam o que pesam na textura (a casa azul
sai bege porque o azul é só a porta e as venezianas). Requer numpy e Pillow.
"""
import glob
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

RAIZ = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
PASTAS = ["assets/prototipo_3d/construcoes", "assets/prototipo_3d/casas"]

TIPOS = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
COMPONENTES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def ler_glb(caminho):
    with open(caminho, "rb") as f:
        f.read(12)
        tamanho_json, _ = struct.unpack("<II", f.read(8))
        cabecalho = json.loads(f.read(tamanho_json))
        tamanho_bin, _ = struct.unpack("<II", f.read(8))
        dados = f.read(tamanho_bin)
    return cabecalho, dados


def acessor(cabecalho, dados, indice):
    a = cabecalho["accessors"][indice]
    vista = cabecalho["bufferViews"][a["bufferView"]]
    tipo = np.dtype(TIPOS[a["componentType"]])
    n = COMPONENTES[a["type"]]
    inicio = vista.get("byteOffset", 0) + a.get("byteOffset", 0)
    passo = vista.get("byteStride", tipo.itemsize * n)
    if passo == tipo.itemsize * n:
        return np.frombuffer(dados, dtype=tipo, count=a["count"] * n, offset=inicio).reshape(a["count"], n)
    saida = np.zeros((a["count"], n), dtype=tipo)
    for i in range(a["count"]):
        saida[i] = np.frombuffer(dados, dtype=tipo, count=n, offset=inicio + i * passo)
    return saida


def textura(cabecalho, dados):
    material = cabecalho["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    imagem = cabecalho["images"][cabecalho["textures"][material]["source"]]
    vista = cabecalho["bufferViews"][imagem["bufferView"]]
    inicio = vista.get("byteOffset", 0)
    return Image.open(io.BytesIO(dados[inicio:inicio + vista["byteLength"]])).convert("RGB")


def linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * (c ** (1 / 2.4)) - 0.055)


def hexa(media):
    s = srgb(media)
    return "#%02x%02x%02x" % tuple(int(round(x * 255)) for x in s)


def medir(caminho):
    cabecalho, dados = ler_glb(caminho)
    primitiva = cabecalho["meshes"][0]["primitives"][0]
    pos = acessor(cabecalho, dados, primitiva["attributes"]["POSITION"]).astype(np.float64)
    uv = acessor(cabecalho, dados, primitiva["attributes"]["TEXCOORD_0"]).astype(np.float64)
    tri = acessor(cabecalho, dados, primitiva["indices"]).reshape(-1).astype(np.int64).reshape(-1, 3)
    imagem = textura(cabecalho, dados)
    largura, altura_px = imagem.size
    pixels = np.asarray(imagem)
    p0, p1, p2 = pos[tri[:, 0]], pos[tri[:, 1]], pos[tri[:, 2]]
    n = np.cross(p1 - p0, p2 - p0)
    area = 0.5 * np.linalg.norm(n, axis=1)
    nn = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    centro = (p0 + p1 + p2) / 3.0
    uvc = (uv[tri[:, 0]] + uv[tri[:, 1]] + uv[tri[:, 2]]) / 3.0
    u = np.clip((uvc[:, 0] % 1.0) * (largura - 1), 0, largura - 1).astype(int)
    v = np.clip((uvc[:, 1] % 1.0) * (altura_px - 1), 0, altura_px - 1).astype(int)
    cor = linear(pixels[v, u].astype(np.float64))
    y_min, y_max = pos[:, 1].min(), pos[:, 1].max()
    altura = y_max - y_min
    rel = (centro[:, 1] - y_min) / altura
    telhado = (nn[:, 1] > 0.35) & (rel > 0.35)
    parede = (np.abs(nn[:, 1]) < 0.3) & (rel > 0.08) & (rel < 0.7)

    def media(mascara):
        if mascara.sum() == 0:
            return None
        peso = area[mascara][:, None]
        return (cor[mascara] * peso).sum(axis=0) / peso.sum()

    mp, mt = media(parede), media(telhado)
    beiral = float(np.percentile(rel[telhado], 8)) if telhado.sum() else 0.6
    corpo = (pos[:, 1] - y_min) / altura
    no_corpo = (corpo > 0.12) & (corpo < 0.5)
    tam = pos.max(axis=0) - pos.min(axis=0)
    # Os percentis 2 e 98, e não o mínimo e o máximo: o degrau, o beiral da varanda e a mureta
    # que sobram de um lado não são a parede, e a caixa tem de ficar POR DENTRO dela.
    x0, x1 = np.percentile(pos[no_corpo, 0], [2, 98])
    z0, z1 = np.percentile(pos[no_corpo, 2], [2, 98])
    return {
        "parede": hexa(mp) if mp is not None else "#b4a28c",
        "telha": hexa(mt) if mt is not None else "#9a5535",
        "beiral": round(beiral, 2),
        "corpo_x": [round(float((x0 - pos[:, 0].min()) / tam[0]), 2), round(float((x1 - pos[:, 0].min()) / tam[0]), 2)],
        "corpo_z": [round(float((z0 - pos[:, 2].min()) / tam[2]), 2), round(float((z1 - pos[:, 2].min()) / tam[2]), 2)],
    }


def main():
    pedidos = set(sys.argv[1:])
    for pasta in PASTAS:
        for caminho in sorted(glob.glob(os.path.join(RAIZ, pasta, "*_tripo.glb"))):
            chave = os.path.basename(caminho).replace("_tripo.glb", "")
            if pedidos and chave not in pedidos:
                continue
            d = medir(caminho)
            print('\t"%s": {"parede": Color("%s"), "telha": Color("%s"), "beiral": %.2f, "corpo_x": [%.2f, %.2f], "corpo_z": [%.2f, %.2f]},'
                  % (chave, d["parede"], d["telha"], d["beiral"], d["corpo_x"][0], d["corpo_x"][1], d["corpo_z"][0], d["corpo_z"][1]))


if __name__ == "__main__":
    main()
