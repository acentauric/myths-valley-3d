"""Planeja AS CLAREIRAS-DESTAQUE DA MATA e escreve data/mapas/clareiras_da_mata.json.

    python tools/mapas/planejar_clareiras_da_mata.py

Lê o mapa (KML já convertido, cenário, sobrevoo do menu), escolhe ~10 lugares dentro
da mata e grava, para cada um, o centro, o raio, a espécie da árvore-destaque, as
pedras em volta e a trilha de terra até a rua mais perto. O jogo só LÊ o JSON: nada é
sorteado a cada carga, e o vale fica igual a cada partida. Rode de novo só quando o
mapa mudar (o resultado é determinístico: a semente é fixa).

O que o planejador evita (tudo em unidades do mundo, 1 u = 4 m):
  - fora da mata, da terra ou dentro da vila; perto da costa, de rio, de rua demais
    (a clareira fica a 22 a 75 u de uma rua, para a trilha ser curta mas existir);
  - os lugares que já têm clareira ou construção (terreiro, gameleira, lombada,
    chapada, fazenda), os pontos do mapa e as zonas de paisagismo;
  - o corredor do sobrevoo do menu (`data/sobrevoo_menu.json`, o campo `olho`);
  - chão torto: o relevo (média ponderada das altitudes dos pontos, como
    `GeoRegionRenderer._terrain_height_at`) não varia mais que ~0,3 u por u na clareira.
"""
import json
import math
import random
from pathlib import Path

from shapely.geometry import LineString, Point, Polygon
from shapely.ops import nearest_points

RAIZ = Path(__file__).resolve().parents[2]
MPU = 4.0  # metros por unidade (data/mapas/regioes.json)
EXAGERO = 2.0  # exagero vertical (idem)
ALVO = 10  # quantas clareiras
SEPARACAO = 64.0  # entre clareiras
DA_RUA = (22.0, 100.0)  # distância da clareira à rua mais perto (borda a borda do centro)
ESPECIES = ["ipe_roxo", "ipe_amarelo", "pau_brasil", "jaqueira", "mangueira",
            "jequitiba", "jatoba", "angico", "massaranduba", "sapucaia"]
# Quanto cada espécie "cabe" (raio da clareira): copas largas pedem mais chão.
RAIOS = {"ipe_roxo": 12.0, "ipe_amarelo": 12.0, "pau_brasil": 12.0, "jaqueira": 14.0,
         "mangueira": 16.0, "jequitiba": 17.0, "jatoba": 15.0, "angico": 13.0,
         "massaranduba": 15.0, "sapucaia": 14.0}
# Escala da árvore-destaque (1,0 é o tamanho do catálogo): maior que a da mata, que é
# o que faz dela um destaque.
ESCALAS = {"ipe_roxo": 1.5, "ipe_amarelo": 1.5, "pau_brasil": 1.5, "jaqueira": 1.3,
           "mangueira": 1.3, "jequitiba": 1.15, "jatoba": 1.3, "angico": 1.4,
           "massaranduba": 1.3, "sapucaia": 1.3}
# As clareiras com casa isolada (no lugar da árvore-destaque): modelo do catálogo.
CASAS = ["casa_taipa_ocre", "casa_taipa_verde"]
RAIO_DA_CASA = 15.0
# Chão pintado: terra batida ("terra") ou folhiço (camada da copa).
CHAO = {"ipe_roxo": "folhico", "ipe_amarelo": "folhico", "pau_brasil": "terra",
        "jaqueira": "folhico", "mangueira": "terra", "jequitiba": "folhico",
        "jatoba": "terra", "angico": "folhico", "massaranduba": "terra", "sapucaia": "folhico"}


def pts(lista):
    return [(p[0] / MPU, p[1] / MPU) for p in lista]


def altura_em(amostras, x, z):
    peso_total = 0.0
    soma = 0.0
    for (px, pz, h) in amostras:
        d2 = (x - px) ** 2 + (z - pz) ** 2
        if d2 < 1e-6:
            return h
        w = 1.0 / d2
        soma += h * w
        peso_total += w
    return soma / peso_total


def main():
    geo = json.loads((RAIZ / "data/mapas/bom_jesus_dos_pobres.json").read_text(encoding="utf8"))
    cen = json.loads((RAIZ / "data/mapas/bom_jesus_dos_pobres_cenario.json").read_text(encoding="utf8"))
    voo = json.loads((RAIZ / "data/sobrevoo_menu.json").read_text(encoding="utf8"))
    zonas = json.loads((RAIZ / "data/paisagismo/zonas_iniciais.json").read_text(encoding="utf8"))

    terra = Polygon(pts(cen["land_polygon_m"]))
    mata_cenica = Polygon(pts(cen["forest_polygon_m"])).buffer(0)
    vila = Polygon(pts(cen["village_polygon_m"])).buffer(0)
    costa = LineString(pts(cen["coastline_m"]))
    ruas, rios, pontos, amostras = [], [], [], []
    mata_kml = None
    areas_abertas = []
    for f in geo["features"]:
        c = pts(f["coordinates_m"])
        if f["kind"] == "road":
            ruas.append(LineString(c))
        elif f["kind"] == "river":
            rios.append(LineString(c))
        elif f["kind"] == "poi":
            pontos.append(Point(c[0]))
            if "source_altitude_m" in f:
                amostras.append((c[0][0], c[0][1], f["source_altitude_m"] / MPU * EXAGERO))
        elif f["kind"] == "area":
            if f["name"] == "Mata":
                mata_kml = Polygon(c).buffer(0)
            elif f["name"] in ("Fazenda", "Praça"):
                areas_abertas.append(Polygon(c).buffer(0))
    todas_ruas = LineString([]) if not ruas else None
    ruas_uniao = ruas[0]
    for r in ruas[1:]:
        ruas_uniao = ruas_uniao.union(r)
    rios_uniao = rios[0]
    for r in rios[1:]:
        rios_uniao = rios_uniao.union(r)

    # Onde a mata nasce: a mata cênica ou a "Mata" do KML, em terra, fora da vila
    # (menos dentro da "Mata" do KML) e das áreas abertas.
    onde_planta = mata_cenica.union(mata_kml) if mata_kml is not None else mata_cenica
    onde_planta = onde_planta.intersection(terra)
    vila_sem_mata = vila.difference(mata_kml) if mata_kml is not None else vila
    onde_planta = onde_planta.difference(vila_sem_mata)
    for a in areas_abertas:
        onde_planta = onde_planta.difference(a)

    # O que fica de fora de qualquer clareira: (geometria, folga além do raio).
    proibidos = [
        (vila, 14.0),
        (costa, 42.0),
        (rios_uniao, 16.0),
    ]
    for p in pontos:
        proibidos.append((p, 26.0))
    for a in areas_abertas:
        proibidos.append((a, 24.0))
    fixos_m = [(-262, -238), (-300, 560), (-24, -1072), (-128, -960), (-128 + 32, -960)]
    fixos_m += [(480, -1156), (468, -1252), (464, -1296), (472, -1192), (440, -1292), (508, -1184)]
    for (x, z) in fixos_m:
        proibidos.append((Point(x / MPU, z / MPU), 34.0))
    for zona in zonas["zonas"]:
        proibidos.append((Polygon(zona["poligono"]).buffer(0), 20.0))
    # O corredor do sobrevoo (olho, em unidades: x, y, z).
    corredor = LineString([(p[0], p[2]) for p in voo["olho"]])
    proibidos.append((corredor, 70.0))
    # O mirante e a serra do oeste: o relevo alto fica de fora pelo critério de declive.

    praca = Point(0, 0)
    rng = random.Random(1887)
    candidatos = []
    minx, minz, maxx, maxz = onde_planta.bounds
    passo = 6.0
    x = minx
    while x <= maxx:
        z = minz
        while z <= maxz:
            candidatos.append((x + rng.uniform(-1.5, 1.5), z + rng.uniform(-1.5, 1.5)))
            z += passo
        x += passo

    def folga_para_ruas(p):
        return ruas_uniao.distance(Point(p))

    def serve(p, raio):
        ponto = Point(p)
        if not onde_planta.contains(ponto.buffer(raio + 6.0)):
            return False
        d_rua = folga_para_ruas(p)
        if d_rua < DA_RUA[0] or d_rua > DA_RUA[1]:
            return False
        for geom, folga in proibidos:
            if geom.distance(ponto) < raio + folga:
                return False
        # Declive: a diferença de altura entre o centro e o anel do raio.
        h0 = altura_em(amostras, p[0], p[1])
        pior = 0.0
        for k in range(12):
            a = k * math.tau / 12.0
            h = altura_em(amostras, p[0] + math.cos(a) * raio, p[1] + math.sin(a) * raio)
            pior = max(pior, abs(h - h0))
        if pior / raio > 0.28:
            return False
        # Chão que passa de 22 u (mirante e serra): fora; baixada demais (alagado): fora.
        if h0 < 1.2 or h0 > 14.0:
            return False
        return True

    # Escolha espalhada: do mais perto da praça (e do jogador) para fora, em faixas,
    # sempre o ponto que mais afasta das já escolhidas e fica entre 70 e 330 u da praça.
    escolhidas = []
    anel = [c for c in candidatos if 40.0 <= praca.distance(Point(c)) <= 330.0]
    rng.shuffle(anel)
    # As de copa larga primeiro: são as que mais custam a achar chão.
    for i, especie in enumerate(sorted(ESPECIES[:ALVO], key=lambda e: -RAIOS[e])):
        raio = RAIOS[especie]
        melhor, melhor_nota = None, -1.0
        for c in anel:
            if any(math.dist(c, e["centro"]) < SEPARACAO for e in escolhidas):
                continue
            if not serve(c, raio):
                continue
            # Nota: longe das outras clareiras (espalha) e perto de ~180 u da praça.
            afastamento = min([math.dist(c, e["centro"]) for e in escolhidas] or [260.0])
            nota = min(afastamento, 260.0) - 0.15 * abs(praca.distance(Point(c)) - 180.0)
            if nota > melhor_nota:
                melhor, melhor_nota = c, nota
        if melhor is None:
            print("sem lugar para", especie)
            continue
        escolhidas.append({"especie": especie, "centro": melhor, "raio": raio})
        print("%-13s centro (%.1f, %.1f) raio %.0f  praca a %.0f u, rua a %.0f u" % (
            especie, melhor[0], melhor[1], raio, praca.distance(Point(melhor)), folga_para_ruas(melhor)))

    # As casas isoladas: os dois melhores lugares que sobram, longe das clareiras de árvore.
    for casa in CASAS:
        melhor, melhor_nota = None, -1.0
        for c in anel:
            if any(math.dist(c, e["centro"]) < SEPARACAO - 16.0 for e in escolhidas):
                continue
            if not serve(c, RAIO_DA_CASA):
                continue
            afastamento = min(math.dist(c, e["centro"]) for e in escolhidas)
            # Casa isolada, mas com trilha curta: prefere a rua perto.
            nota = min(afastamento, 120.0) - 1.2 * max(0.0, folga_para_ruas(c) - 40.0) - 0.15 * abs(praca.distance(Point(c)) - 150.0)
            if nota > melhor_nota:
                melhor, melhor_nota = c, nota
        if melhor is None:
            print("sem lugar para", casa)
            continue
        escolhidas.append({"especie": "", "casa": casa, "centro": melhor, "raio": RAIO_DA_CASA})
        print("%-13s centro (%.1f, %.1f) raio %.0f  praca a %.0f u, rua a %.0f u" % (
            casa, melhor[0], melhor[1], RAIO_DA_CASA, praca.distance(Point(melhor)), folga_para_ruas(melhor)))

    saida = []
    for i, e in enumerate(escolhidas):
        especie = e["especie"]
        cx, cz = e["centro"]
        raio = e["raio"]
        r = random.Random(1887 + i * 131)
        item = {"especie": especie, "centro": [round(cx, 2), round(cz, 2)], "raio": raio,
                "escala": ESCALAS.get(especie, 1.0), "giro": round(r.uniform(0, math.tau), 3),
                "chao": CHAO.get(especie, "terra")}
        if "casa" in e:
            item["casa"] = e["casa"]
        saida.append(item)

    # A trilha de cada uma: do centro da rua mais perto até a borda da clareira,
    # sinuosa e sem atravessar rio nem clareira alheia.
    for i, c in enumerate(saida):
        centro = Point(c["centro"])
        rua_perto = nearest_points(ruas_uniao, centro)[0]
        ra = (rua_perto.x, rua_perto.y)
        rc = tuple(c["centro"])
        comprimento = math.dist(ra, rc)
        n = max(int(comprimento / 6.0), 4)
        rr = random.Random(777 + i * 17)
        fase = rr.uniform(0, math.tau)
        amplitude = rr.uniform(1.6, 2.8)
        ondas = rr.uniform(1.3, 2.2)
        dx, dz = (rc[0] - ra[0]) / comprimento, (rc[1] - ra[1]) / comprimento
        nx, nz = -dz, dx
        caminho = []
        for k in range(n + 1):
            t = k / n
            # A trilha para na borda da clareira (o centro tem a árvore-destaque).
            alvo = comprimento - c["raio"] * (0.4 if "casa" in c else 0.55)
            s = alvo * t
            lado = math.sin(fase + t * ondas * math.pi) * amplitude * math.sin(math.pi * t) ** 0.5
            caminho.append([round(ra[0] + dx * s + nx * lado, 2), round(ra[1] + dz * s + nz * lado, 2)])
        c["trilha"] = caminho
        linha = LineString(caminho)
        assert linha.distance(rios_uniao) > 6.0, "a trilha %d toca um rio" % i
        # Pedras: ângulos fora do rumo da trilha.
        rumo = math.atan2(-dz, -dx)  # do centro para a rua
        pedras = []
        r = random.Random(4242 + i * 29)
        quantas = r.randint(2, 3) if "casa" in c else r.randint(3, 6)
        # A casa ocupa o miolo: as pedras ficam para fora do terreiro dela.
        mais_perto = 0.62 if "casa" in c else 0.38
        tipos = ["pedras", "pedras", "penedo_lapa", "pedras"]
        tentativas = 0
        while len(pedras) < quantas and tentativas < 200:
            tentativas += 1
            ang = r.uniform(0, math.tau)
            if abs(math.remainder(ang - rumo, math.tau)) < 0.45:
                continue
            dist = r.uniform(mais_perto, 0.85) * c["raio"]
            ponto = (rc[0] + math.cos(ang) * dist, rc[1] + math.sin(ang) * dist)
            if any(math.dist(ponto, (rc[0] + q["dx"], rc[1] + q["dz"])) < 4.2 for q in pedras):
                continue
            if linha.distance(Point(ponto)) < 3.5:
                continue
            tipo = r.choice(tipos)
            if tipo == "penedo_lapa" and any(q["tipo"] == "penedo_lapa" for q in pedras):
                tipo = "pedras"
            escala = r.uniform(0.28, 0.42) if tipo == "penedo_lapa" else r.uniform(0.9, 1.5)
            pedras.append({"tipo": tipo, "dx": round(ponto[0] - rc[0], 2), "dz": round(ponto[1] - rc[1], 2),
                           "escala": round(escala, 2), "giro": round(r.uniform(0, math.tau), 3)})
        c["pedras"] = pedras
        if "casa" in c:
            # A porta (o +Z do modelo) olha para onde a trilha chega.
            c["giro"] = round(math.atan2(math.cos(rumo), math.sin(rumo)), 3)

    arquivo = {
        "descricao": "Clareiras-destaque da mata (tools/mapas/planejar_clareiras_da_mata.py): "
                     "uma árvore de espécie diferente em cada uma, pedras em volta, chão pintado e "
                     "uma trilha de terra até a rua. Posições em unidades do mundo (1 u = 4 m).",
        "clareiras": saida,
    }
    caminho = RAIZ / "data/mapas/clareiras_da_mata.json"
    caminho.write_text(json.dumps(arquivo, ensure_ascii=False, indent=1) + "\n", encoding="utf8")
    print("gravado", caminho, len(saida), "clareiras")


if __name__ == "__main__":
    main()
