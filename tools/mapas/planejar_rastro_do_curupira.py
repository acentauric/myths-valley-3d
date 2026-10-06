"""Planeja O RASTRO DO CURUPIRA e escreve data/rastro_do_curupira.json.

    python tools/mapas/planejar_rastro_do_curupira.py

Lê o mapa (KML já convertido, cenário, sobrevoo do menu, clareiras da mata), escolhe 4 trilhas de
pegadas BEM DENTRO DA MATA e grava cada pegada: onde pisou, para onde os dedos apontam e de que
pé é. O jogo só LÊ o JSON (`scripts/prototipo_3d/rastro_do_curupira.gd`): nada é sorteado a cada
carga. O resultado é determinístico (semente fixa); rode de novo só quando o mapa mudar.

AS PEGADAS SÃO AO CONTRÁRIO. O Curupira anda de frente com os pés virados para trás: a trilha vai de
`inicio` a `marco`, e os dedos de cada pegada apontam para o INÍCIO. Quem segue os dedos volta para
a clareira, e o dono do rastro está no outro lado, onde ele foi de verdade. Por isso cada pegada
leva o `yaw` dos dedos (o rumo do caminho mais meio giro) e o pé (`lado`: 1 esquerdo, 0 direito).

O que o planejador evita (tudo em unidades do mundo, 1 u = 4 m; folgas MAIORES que as de
`scripts/prototipo_3d/mata_funda.gd`, que é quem o jogo usa para dizer "mata funda" — o portão
`rastro_do_curupira` confere as duas contas juntas):
  - fora da mata, da terra ou dentro da vila; perto de rua, de costa, de rio, de ponto do mapa, de
    área aberta (fazenda, praça) e das clareiras (só a ENTRADA do rastro sai da borda de uma clareira
    para o jogador que visita a clareira achar a primeira pegada);
  - os lugares que já têm construção (terreiro, gameleira, lombada, chapada, fazenda) e as zonas de
    paisagismo; o corredor do sobrevoo do menu (`data/sobrevoo_menu.json`);
  - chão torto: o relevo (média ponderada das altitudes, como `GeoRegionRenderer._terrain_height_at`)
    não varia mais que 0,3 u por u em volta de nenhuma pegada.
"""
import json
import math
import random
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon

RAIZ = Path(__file__).resolve().parents[2]
MPU = 4.0  # metros por unidade (data/mapas/regioes.json)
EXAGERO = 2.0  # exagero vertical (idem)
SEMENTE = 1887
QUANTAS = 4  # trilhas
PASSO = 1.15  # entre uma pegada e a próxima (u): passo largo de quem anda apressado
LATERAL = 0.2  # meia distância entre o pé esquerdo e o direito (u)
CORPO = 50  # pegadas depois da entrada (a parte funda do rastro)
ENTRADA = 26  # pegadas entre a borda da clareira e o começo do fundo (a folga da clareira, 14 u, mais o passeio)
FOLGAS_FUNDO = {  # as do jogo (mata_funda.gd): a pegada só vale como gatilho se passa nelas
    "vila": 30.0, "rua": 24.0, "ponto": 28.0, "clareira": 14.0, "area": 20.0, "costa": 30.0, "rio": 14.0,
}
MARGEM_EXTRA = 4.0  # o corpo do rastro fica mais fundo que o mínimo do jogo
SEPARACAO = 60.0  # entre as clareiras de onde saem
ENTRE_RASTROS = 30.0  # u: menor distância entre dois rastros
DECLIVE_MAXIMO = 0.3
BORDA_DO_QUADRO = 60.0  # u: o rastro não chega perto da borda do mundo


def pts(lista):
    return [(p[0] / MPU, p[1] / MPU) for p in lista]


class Relevo:
    """A altura do chão: média ponderada das altitudes dos pontos do mapa (1/d²)."""

    def __init__(self, amostras):
        self.px = np.array([a[0] for a in amostras])
        self.pz = np.array([a[1] for a in amostras])
        self.h = np.array([a[2] for a in amostras])

    def altura(self, x, z):
        d2 = (np.asarray(x)[..., None] - self.px) ** 2 + (np.asarray(z)[..., None] - self.pz) ** 2
        w = 1.0 / np.maximum(d2, 1e-6)
        return (self.h * w).sum(-1) / w.sum(-1)

    def declive(self, x, z, raio=2.0):
        h0 = self.altura(x, z)
        pior = np.zeros_like(h0)
        for k in range(8):
            a = k * math.tau / 8.0
            pior = np.maximum(pior, np.abs(self.altura(x + math.cos(a) * raio, z + math.sin(a) * raio) - h0))
        return pior / raio


def main():
    geo = json.loads((RAIZ / "data/mapas/bom_jesus_dos_pobres.json").read_text(encoding="utf8"))
    cen = json.loads((RAIZ / "data/mapas/bom_jesus_dos_pobres_cenario.json").read_text(encoding="utf8"))
    voo = json.loads((RAIZ / "data/sobrevoo_menu.json").read_text(encoding="utf8"))
    zonas = json.loads((RAIZ / "data/paisagismo/zonas_iniciais.json").read_text(encoding="utf8"))
    clareiras = json.loads((RAIZ / "data/mapas/clareiras_da_mata.json").read_text(encoding="utf8"))["clareiras"]

    terra = Polygon(pts(cen["land_polygon_m"])).buffer(0)
    mata_cenica = Polygon(pts(cen["forest_polygon_m"])).buffer(0)
    vila = Polygon(pts(cen["village_polygon_m"])).buffer(0)
    costa = LineString(pts(cen["coastline_m"]))
    ruas, rios, pontos, amostras, areas_abertas = [], [], [], [], []
    mata_kml = None
    quadro = None
    for f in geo["features"]:
        c = pts(f["coordinates_m"])
        if f["kind"] == "map_frame":
            quadro = Polygon(c).buffer(0)
        elif f["kind"] == "road":
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
    relevo = Relevo(amostras)
    # O quadro do mapa (16:9) é o mundo jogável: o rastro fica longe da borda dele.
    assert quadro is not None, "o mapa não traz o quadro (map_frame)"
    onde_ha_mundo = quadro.buffer(-BORDA_DO_QUADRO)

    def uniao(linhas):
        resultado = linhas[0]
        for linha in linhas[1:]:
            resultado = resultado.union(linha)
        return resultado

    ruas_u, rios_u = uniao(ruas), uniao(rios)
    onde_planta = mata_cenica.union(mata_kml) if mata_kml is not None else mata_cenica
    onde_planta = onde_planta.intersection(terra).intersection(onde_ha_mundo)
    vila_sem_mata = vila.difference(mata_kml) if mata_kml is not None else vila
    onde_planta = onde_planta.difference(vila_sem_mata)
    for a in areas_abertas:
        onde_planta = onde_planta.difference(a)

    # (geometria, folga do jogo): a mesma lista de `mata_funda.gd`, mais os lugares que o jogo
    # conhece só por nome (as âncoras de casa) e que o planejador das clareiras já fixa à mão.
    fixos_m = [(-262, -238), (-300, 560), (-24, -1072), (-128, -960), (-128 + 32, -960),
               (480, -1156), (468, -1252), (464, -1296), (472, -1192), (440, -1292), (508, -1184)]
    proibidos = [(vila.boundary, FOLGAS_FUNDO["vila"]), (ruas_u, FOLGAS_FUNDO["rua"]),
                 (costa, FOLGAS_FUNDO["costa"]), (rios_u, FOLGAS_FUNDO["rio"])]
    proibidos += [(p, FOLGAS_FUNDO["ponto"]) for p in pontos]
    proibidos += [(a, FOLGAS_FUNDO["area"]) for a in areas_abertas]
    proibidos += [(Point(x / MPU, z / MPU), 34.0) for (x, z) in fixos_m]
    proibidos += [(Polygon(z["poligono"]).buffer(0), 20.0) for z in zonas["zonas"]]
    proibidos += [(Point(c["centro"]), c["raio"] + FOLGAS_FUNDO["clareira"]) for c in clareiras]
    proibidos.append((LineString([(p[0], p[2]) for p in voo["olho"]]), 70.0))
    shapely.prepare(onde_planta)

    def margem(x, z, extra=0.0):
        """Quanto cada ponto passa da folga mais apertada (negativo: reprova). Vetorizado."""
        xs, zs = np.atleast_1d(x), np.atleast_1d(z)
        pontos_np = shapely.points(xs, zs)
        pior = np.full(len(xs), np.inf)
        for geom, folga in proibidos:
            pior = np.minimum(pior, shapely.distance(geom, pontos_np) - folga)
        dentro = shapely.contains_xy(onde_planta, xs, zs)
        return np.where(dentro, pior - extra, -1e9)

    def serve(x, z, extra=0.0):
        h = relevo.altura(x, z)
        return (margem(x, z, extra) > 0.0) & (relevo.declive(x, z) <= DECLIVE_MAXIMO) & (h > 1.2) & (h < 14.0)

    rng = random.Random(SEMENTE)
    escolhidas = []
    # Cada rastro nasce na borda de uma clareira (a de casa fica de fora: tem morador em volta) e
    # segue para onde a mata é mais funda. Testa 360 rumos por clareira e fica com o melhor.
    candidatas = []
    for c in clareiras:
        if c.get("casa"):
            continue
        cx, cz = c["centro"]
        rua_trilha = c["trilha"][0]
        rumo_da_trilha = math.atan2(rua_trilha[1] - cz, rua_trilha[0] - cx)
        for graus in range(0, 360, 2):
            a = math.radians(graus)
            # Longe do rumo da trilha de terra da clareira (a que vai para a rua).
            if abs(math.remainder(a - rumo_da_trilha, math.tau)) < math.radians(75):
                continue
            ponto0 = (cx + math.cos(a) * (c["raio"] + 3.5), cz + math.sin(a) * (c["raio"] + 3.5))
            caminho = andar(ponto0, a, ENTRADA + CORPO, rng_local=random.Random(SEMENTE + graus))
            xs = np.array([p[0] for p in caminho])
            zs = np.array([p[1] for p in caminho])
            fundo_ok = serve(xs[ENTRADA:], zs[ENTRADA:], MARGEM_EXTRA)
            if not fundo_ok.all():
                continue
            # O ponto de partida e a entrada só precisam de chão que preste, e de terra firme.
            h = relevo.altura(xs[:ENTRADA], zs[:ENTRADA])
            if not (relevo.declive(xs[:ENTRADA], zs[:ENTRADA]) <= DECLIVE_MAXIMO).all() or not (h > 1.0).all():
                continue
            if not shapely.contains_xy(terra, xs[:ENTRADA], zs[:ENTRADA]).all():
                continue
            nota = float(margem(xs[ENTRADA:], zs[ENTRADA:]).min())
            candidatas.append({"clareira": c, "nota": nota, "rumo": graus, "caminho": caminho,
                               "linha": LineString(caminho)})
    candidatas.sort(key=lambda k: -k["nota"])
    for cand in candidatas:
        if len(escolhidas) >= QUANTAS:
            break
        # Uma trilha por clareira, as clareiras longe umas das outras e os rastros também.
        if any(cand["clareira"] is e["clareira"] for e in escolhidas):
            continue
        if any(math.dist(cand["clareira"]["centro"], e["clareira"]["centro"]) < SEPARACAO for e in escolhidas):
            continue
        if any(cand["linha"].distance(e["linha"]) < ENTRE_RASTROS for e in escolhidas):
            continue
        escolhidas.append(cand)
    assert len(escolhidas) >= 3, "poucas trilhas: %d" % len(escolhidas)

    saida = []
    for i, e in enumerate(escolhidas):
        caminho = e["caminho"]
        r = random.Random(SEMENTE + 313 * (i + 1))
        pegadas = []
        for k, (x, z) in enumerate(caminho):
            if k + 1 < len(caminho):
                dx, dz = caminho[k + 1][0] - x, caminho[k + 1][1] - z
            else:
                dx, dz = x - caminho[k - 1][0], z - caminho[k - 1][1]
            n = math.hypot(dx, dz)
            dx, dz = dx / n, dz / n
            esquerdo = k % 2 == 0
            # A esquerda de quem anda para (dx, dz): (dz, -dx) — a mesma conta de `pegadas.gd`.
            lado = (dz, -dx)
            sinal = 1.0 if esquerdo else -1.0
            px = x + lado[0] * LATERAL * sinal + r.uniform(-0.04, 0.04)
            pz = z + lado[1] * LATERAL * sinal + r.uniform(-0.04, 0.04)
            rumo = math.atan2(dx, dz)  # para onde o corpo anda (a convenção de `pegadas.gd`)
            yaw = math.remainder(rumo + math.pi, math.tau)  # os dedos apontam para trás
            funda = bool(serve(px, pz)[0]) and k >= ENTRADA - 2
            pegadas.append([round(px, 2), round(pz, 2), round(yaw, 3), 1 if esquerdo else 0, 1 if funda else 0])
        marco = caminho[-1]
        saida.append({
            "id": "rastro_%d" % (i + 1),
            "clareira": e["clareira"]["especie"],
            "inicio": [round(caminho[0][0], 2), round(caminho[0][1], 2)],
            "marco": [round(marco[0], 2), round(marco[1], 2)],
            "pegadas": pegadas,
        })
        fundas = sum(p[4] for p in pegadas)
        print("%s: da clareira %-13s rumo %3d graus, %d pegadas (%d fundas), margem do fundo %.0f u, fim (%.0f, %.0f)" % (
            saida[-1]["id"], e["clareira"]["especie"], e["rumo"], len(pegadas), fundas, e["nota"], marco[0], marco[1]))

    arquivo = {
        "descricao": "O rastro do Curupira (tools/mapas/planejar_rastro_do_curupira.py): pegadas de pé de criança "
                     "com os dedos virados PARA TRÁS, em trilhas que saem da borda de uma clareira e entram na mata funda. "
                     "Cada pegada: [x, z, yaw dos dedos, 1 se é o pé esquerdo, 1 se está na mata funda]. "
                     "Posições em unidades do mundo (1 u = 4 m); yaw na convenção de pegadas.gd (rumo do corpo = (sin yaw, cos yaw)).",
        "passo": PASSO,
        "trilhas": saida,
    }
    destino = RAIZ / "data/rastro_do_curupira.json"
    destino.write_text(json.dumps(arquivo, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf8")
    print("gravado", destino, len(saida), "trilhas")


def andar(inicio, rumo, passos, rng_local):
    """Um passeio suave: o rumo muda pouco a cada passo, e a curva muda de lado de vez em quando."""
    x, z = inicio
    curva = rng_local.uniform(-0.05, 0.05)
    caminho = []
    for _ in range(passos):
        caminho.append((x, z))
        if rng_local.random() < 0.08:
            curva = rng_local.uniform(-0.06, 0.06)
        rumo += curva + rng_local.uniform(-0.02, 0.02)
        x += math.cos(rumo) * PASSO
        z += math.sin(rumo) * PASSO
    return caminho


if __name__ == "__main__":
    main()
