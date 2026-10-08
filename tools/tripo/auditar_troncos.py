"""Audita o TRONCO das árvores do catálogo direto nos GLBs, sem abrir o Godot.

Duas medidas, as mesmas das issues #156 (troncos que parecem vazados) e #150
(colisão das árvores):

  de-costas  de cada raio horizontal que cruza o pé da árvore (16 direções, 10
             alturas do pé até metade da árvore, no máximo 2,5 m, 9 afastamentos
             de até 1,3 raio do tronco), a fração cujo PRIMEIRO triângulo é de
             costas. Com o descarte de costas ligado (catalogo_assets.gd), tronco
             com a malha virada para dentro some por fora e aparece oco. As
             íntegras dão 0 a 6%; as de costas, 12% a 79%. É o que
             `tests/troncos_fechados.gd` cobra, e `CatalogoAssets.TRONCO_DE_COSTAS`
             é a lista de quem passa do limite.
  raio       o raio VISÍVEL do tronco: a mediana, em 16 direções e quatro alturas
             (0,4; 0,8; 1,2; 1,6 m), da distância do eixo ao primeiro triângulo.
             Compara-se ao `tronco` do catálogo, que é o raio do cilindro de
             colisão; o corpo do jogador soma 0,28 e o cilindro só vai até 3 m.

Uso (precisa de numpy):
    python tools/tripo/auditar_troncos.py [de-costas|raio] [chave ...]

Escalas e pés seguem `CatalogoAssets.instanciar`: a altura do catálogo normaliza o
modelo, com o pé em y = 0. O eixo é a mediana do chão (x, z) dos vértices de 0,3 a
0,9 m. Em árvore de vários fustes (ingazeiro, mangue, touceira de bambu) ou de
sapopemas (gameleira) o eixo e o raio visível não descrevem um tronco só: leia a
coluna com isso em mente (as exceções estão em `tests/colisao_do_catalogo_das_arvores.gd`).
"""
import json
import os
import re
import struct
import sys

import numpy as np

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATALOGO = os.path.join(RAIZ, "scripts", "prototipo_3d", "catalogo_assets.gd")
PASTA = os.path.join(RAIZ, "assets", "prototipo_3d")

TIPOS = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
COMPONENTES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

DIRECOES = 16
ALTURAS = 10
AFASTAMENTOS = 9
DISTANCIA = 6.0
LIMITE_DE_COSTAS = 0.09


def ler_glb(caminho):
    with open(caminho, "rb") as f:
        dados = f.read()
    _, _, comprimento = struct.unpack("<III", dados[:12])
    depois = 12
    json_ = None
    binario = b""
    while depois < comprimento:
        tamanho, tipo = struct.unpack("<II", dados[depois:depois + 8])
        depois += 8
        pedaco = dados[depois:depois + tamanho]
        depois += tamanho
        if tipo == 0x4E4F534A:
            json_ = json.loads(pedaco)
        elif tipo == 0x004E4942:
            binario = pedaco
    return json_, binario


def acessor(g, binario, indice):
    a = g["accessors"][indice]
    vista = g["bufferViews"][a["bufferView"]]
    n = COMPONENTES[a["type"]]
    tipo = np.dtype(TIPOS[a["componentType"]])
    passo = vista.get("byteStride", n * tipo.itemsize)
    comeco = vista.get("byteOffset", 0) + a.get("byteOffset", 0)
    bruto = np.frombuffer(binario, dtype=np.uint8)
    saida = np.empty((a["count"], n), dtype=tipo)
    for k in range(n):
        base = comeco + np.arange(a["count"]) * passo + k * tipo.itemsize
        pedacos = np.stack([bruto[base + j] for j in range(tipo.itemsize)], axis=1).copy()
        saida[:, k] = pedacos.view(tipo).reshape(-1)
    return saida


def matriz_do_no(no):
    if "matrix" in no:
        return np.array(no["matrix"]).reshape(4, 4).T
    m = np.eye(4)
    x, y, z, w = no.get("rotation", [0, 0, 0, 1])
    giro = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    m[:3, :3] = giro * np.array(no.get("scale", [1, 1, 1]))[None, :]
    m[:3, 3] = no.get("translation", [0, 0, 0])
    return m


def triangulos(caminho, altura):
    """Triângulos (T, 3, 3) em metros, com o pé em y = 0 e a altura do catálogo."""
    g, binario = ler_glb(caminho)
    blocos = []

    def descer(i, pai):
        no = g["nodes"][i]
        m = pai @ matriz_do_no(no)
        if "mesh" in no:
            for prim in g["meshes"][no["mesh"]]["primitives"]:
                v = acessor(g, binario, prim["attributes"]["POSITION"]).astype(np.float64)
                v = (m @ np.c_[v, np.ones(len(v))].T).T[:, :3]
                if "indices" in prim:
                    ix = acessor(g, binario, prim["indices"]).reshape(-1).astype(np.int64)
                else:
                    ix = np.arange(len(v))
                blocos.append(v[ix.reshape(-1, 3)])
        for filho in no.get("children", []):
            descer(filho, m)

    for i in g["scenes"][g.get("scene", 0)]["nodes"]:
        descer(i, np.eye(4))
    t = np.concatenate(blocos)
    menor = t[:, :, 1].min()
    escala = altura / (t[:, :, 1].max() - menor)
    return (t - np.array([0.0, menor, 0.0])) * escala


def primeiro_acerto(a, b, c, origens, direcao):
    """Para cada origem, (distância do primeiro acerto, de frente?). Möller–Trumbore
    sem descarte. Convenção do glTF: frente é o sentido anti-horário."""
    e1, e2 = b - a, c - a
    p = np.cross(direcao[None, None, :], e2[None, :, :])
    det = (p * e1[None]).sum(2)
    ok = np.abs(det) > 1e-14
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    t_ = origens[:, None, :] - a[None]
    u = (t_ * p).sum(2) * inv
    q = np.cross(t_, e1[None])
    v = (direcao[None, None, :] * q).sum(2) * inv
    dist = (e2[None] * q).sum(2) * inv
    bate = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (dist > 1e-6)
    dist = np.where(bate, dist, np.inf)
    j = np.argmin(dist, axis=1)
    linhas = np.arange(len(origens))
    det = np.broadcast_to(det, dist.shape)
    return dist[linhas, j], det[linhas, j] > 0.0


def eixo_do_tronco(t):
    centro = t[:, :, 1].mean(1)
    faixa = t[(centro > 0.3) & (centro < 0.9)].reshape(-1, 3)
    if len(faixa) == 0:
        return np.zeros(2)
    return np.array([np.median(faixa[:, 0]), np.median(faixa[:, 2])])


def fracao_de_costas(t, raio_do_tronco, altura):
    eixo = eixo_do_tronco(t)
    maxima = min(2.5, 0.5 * altura)
    y = t[:, :, 1]
    t = t[(y.max(1) > 0.2) & (y.min(1) < maxima + 0.2)]
    a, b, c = t[:, 0], t[:, 1], t[:, 2]
    acertos = de_costas = 0
    for k in range(DIRECOES):
        ang = 2 * np.pi * k / DIRECOES
        d = np.array([np.cos(ang), 0.0, np.sin(ang)])
        lado = np.array([-d[2], 0.0, d[0]])
        origens = np.array([
            [eixo[0] + lado[0] * o - d[0] * DISTANCIA, h, eixo[1] + lado[2] * o - d[2] * DISTANCIA]
            for h in np.linspace(0.3, maxima, ALTURAS)
            for o in np.linspace(-raio_do_tronco * 1.3, raio_do_tronco * 1.3, AFASTAMENTOS)])
        dist, de_frente = primeiro_acerto(a, b, c, origens, d)
        bateu = np.isfinite(dist)
        acertos += int(bateu.sum())
        de_costas += int((bateu & ~de_frente).sum())
    return acertos, de_costas / max(acertos, 1)


def raio_visivel(t, altura):
    eixo = eixo_do_tronco(t)
    y = t[:, :, 1]
    t = t[(y.max(1) > 0.1) & (y.min(1) < 3.0)]
    a, b, c = t[:, 0], t[:, 1], t[:, 2]
    medidas = []
    for h in (0.4, 0.8, 1.2, 1.6):
        if h > 0.6 * altura:
            continue
        raios = []
        for k in range(DIRECOES):
            ang = 2 * np.pi * k / DIRECOES
            d = np.array([np.cos(ang), 0.0, np.sin(ang)])
            origem = np.array([[eixo[0] - d[0] * 8, h, eixo[1] - d[2] * 8]])
            dist, _ = primeiro_acerto(a, b, c, origem, d)
            if np.isfinite(dist[0]):
                raios.append(8.0 - dist[0])
        if raios:
            medidas.append(float(np.median(raios)))
    return (float(np.median(medidas)) if medidas else float("nan")), medidas


def pecas_do_catalogo():
    """{chave: (arquivo, altura, tronco ou None)} das árvores com `altura`."""
    fonte = open(CATALOGO, encoding="utf-8").read()
    pecas = {}
    for m in re.finditer(r'^\t"(\w+)": \{"tripo": "(arvores/\w+_tripo\.glb)"(.*?)\}', fonte, re.M | re.S):
        chave, arquivo, resto = m.groups()
        altura = re.search(r'"altura": ([\d.]+)', resto)
        tronco = re.search(r'"tronco": ([\d.]+)', resto)
        if altura:
            pecas[chave] = (arquivo, float(altura.group(1)), float(tronco.group(1)) if tronco else None)
    return pecas


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    modo = sys.argv[1] if len(sys.argv) > 1 else "de-costas"
    so = set(sys.argv[2:])
    for chave, (arquivo, altura, tronco) in sorted(pecas_do_catalogo().items()):
        if so and chave not in so:
            continue
        if not so and tronco is None and not chave.endswith("_longe"):
            continue
        caminho = os.path.join(PASTA, arquivo)
        if not os.path.exists(caminho):
            continue
        t = triangulos(caminho, altura)
        if modo == "de-costas":
            acertos, fracao = fracao_de_costas(t, tronco or 0.4, altura)
            marca = "  <- de costas" if fracao > LIMITE_DE_COSTAS else ""
            print("%-20s acertos=%4d  de costas=%3.0f%%%s" % (chave, acertos, fracao * 100, marca))
        else:
            visivel, amostras = raio_visivel(t, altura)
            if tronco is None:
                print("%-20s altura=%5.1f  sem colisão no catálogo  visível=%.2f" % (chave, altura, visivel))
            else:
                print("%-20s altura=%5.1f  tronco=%.2f  visível=%.2f  diferença=%+.2f  (%s)" % (
                    chave, altura, tronco, visivel, tronco - visivel, " ".join("%.2f" % x for x in amostras)))


if __name__ == "__main__":
    main()
