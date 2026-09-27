"""Gera o mapa de profundidade do mar (maré cheia) a partir da carta náutica DHN 1108.

A carta raster (GeoTIFF + KAP da DHN, "Baía de Todos os Santos — Porto de São Roque e
proximidades", 1:15.000) fica em `.assets-raw/cartas_nauticas/` e não vai para o git.
Ela traz as faixas de profundidade em cores chapadas, referidas ao nível de redução
(maré mais baixa):

    terra (creme) · intermarés, seca na baixa-mar (verde) · 0–5 m (azul) ·
    5–10 m (azul-claro) · mais de 10 m (branco)

Cada célula da grade recebe a faixa da carta; dentro de uma faixa, a profundidade é
interpolada pela distância até as faixas vizinhas mais rasa e mais funda. Soma-se a
altura da maré cheia (PREAMAR_M) para ter a lâmina d'água do jogo.

Dentro do quadro Mapa (os limites do cenário) a terra é o polígono do jogo; fora dele,
a terra da carta continua como relevo distante (Bom Jesus fica no continente), com a
altitude interpolada dos pontos do KML como o terreno do jogo faz.

Saída: elevação acima da preamar em float16 cru (little-endian, linha a linha de norte
a sul), normalizada entre ELEVACAO_MIN_M e ELEVACAO_MAX_M, e o bloco "bathymetry" do
cenário da região. O Godot monta a textura do fundo e a colisão direto desses bytes.
Execute de novo se a carta, a grade, o cenário ou os parâmetros mudarem.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

PROJECT = Path(__file__).resolve().parents[2]
RAW = PROJECT.parent / ".assets-raw/cartas_nauticas"
GEOMETRY = PROJECT / "data/mapas/bom_jesus_dos_pobres.json"
SCENARIO = PROJECT / "data/mapas/bom_jesus_dos_pobres_cenario.json"
OUTPUT = PROJECT / "data/mapas/bom_jesus_dos_pobres_batimetria.bin"
OUTPUT_RES = "res://data/mapas/bom_jesus_dos_pobres_batimetria.bin"

# Grade em metros locais (x = leste, z = sul, origem na Praça), coberta pela carta.
GRADE = {"min_x": -2000.0, "max_x": 3500.0, "min_z": -1500.0, "max_z": 3500.0}
CELULA_M = 10.0
# Preamar de sizígia na Baía de Todos os Santos, acima do nível de redução da carta.
PREAMAR_M = 2.4
ELEVACAO_MIN_M = -35.0
ELEVACAO_MAX_M = 100.0
# Terra do jogo: o fundo fica logo abaixo da água, escondido pelo terreno.
LAMINA_SOB_TERRA_M = 0.3
# Relevo fora do quadro: sobe da costa até a altitude interpolada nesta distância
# (a mesma faixa costeira de ground_height_at).
FAIXA_COSTEIRA_M = 80.0

# Faixas da carta: cor, profundidade mínima e máxima (m, abaixo do nível de redução).
# A intermarés tem altura acima do nível (profundidade negativa) até a preamar.
TERRA, INTERMARES, RASO, MEDIO, FUNDO = range(5)
CORES = {
    TERRA: (255, 224, 153),
    INTERMARES: (145, 217, 48),
    RASO: (153, 255, 255),
    MEDIO: (217, 255, 255),
    FUNDO: (255, 255, 255),
}
FAIXAS = {RASO: (0.0, 5.0), MEDIO: (5.0, 10.0)}
# Intermarés: face de praia curta e íngreme, depois a planície de lama quase plana
# (sondagens de secagem da carta: 0,1 a 1,4 m).
FACE_PRAIA_M = 30.0
ALTURA_PLANICIE_M = 1.0
# Além da curva de 10 m o canal aprofunda até ~28 m (sondagens de 20 a 33 m).
FUNDO_EXTRA_M = 18.0
FUNDO_RAMPA_M = 35.0
# Faixa rasa sem vizinha mais funda por perto (a grande planície a nordeste).
RASO_RAMPA_M = 700.0
RASO_RAMPA_PESO = 0.75


def georreferencia(kap: Path) -> tuple[np.ndarray, np.ndarray]:
    """Ajusta pixel = a + b·lat + c·lon aos pontos REF do cabeçalho KAP."""
    header = kap.read_bytes()[:200000].split(b"\x1a")[0].decode("latin1")
    refs = [tuple(map(float, m)) for m in re.findall(r"REF/\d+,(\d+),(\d+),(-?[\d.]+),(-?[\d.]+)", header)]
    a = np.array([[1.0, lat, lon] for _, _, lat, lon in refs])
    cx = np.linalg.lstsq(a, np.array([r[0] for r in refs]), rcond=None)[0]
    cy = np.linalg.lstsq(a, np.array([r[1] for r in refs]), rcond=None)[0]
    return cx, cy


def classificar(rgb: np.ndarray) -> np.ndarray:
    """Faixa de cada pixel pela cor mais próxima; texto e linhas herdam a vizinha."""
    paleta = np.array([CORES[k] for k in range(5)], dtype=np.int32)
    dist = ((rgb[:, :, None, :].astype(np.int32) - paleta[None, None]) ** 2).sum(-1)
    classe = dist.argmin(-1)
    classe[dist.min(-1) > 30 * 30] = -1
    _, (iy, ix) = ndimage.distance_transform_edt(classe < 0, return_indices=True)
    return classe[iy, ix]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--carta", type=Path, default=RAW / "1108geotiff/1108geotiff.tif")
    parser.add_argument("--kap", type=Path, default=RAW / "1108/110801.KAP")
    args = parser.parse_args()

    projection = json.loads(GEOMETRY.read_text(encoding="utf-8"))["projection"]
    cx, cy = georreferencia(args.kap)
    Image.MAX_IMAGE_PIXELS = None
    carta = np.asarray(Image.open(args.carta).convert("RGB"))

    xs = np.arange(GRADE["min_x"] + CELULA_M / 2, GRADE["max_x"], CELULA_M)
    zs = np.arange(GRADE["min_z"] + CELULA_M / 2, GRADE["max_z"], CELULA_M)
    gx, gz = np.meshgrid(xs, zs)
    lat = projection["origin_lat"] - gz / projection["meters_per_degree_lat"]
    lon = projection["origin_lon"] + gx / projection["meters_per_degree_lon"]
    px = np.clip(np.rint(cx[0] + cx[1] * lat + cx[2] * lon), 0, carta.shape[1] - 1).astype(int)
    # A carta termina em ~12°48'S: a faixa ao norte repete a última linha dela.
    py = np.clip(np.rint(cy[0] + cy[1] * lat + cy[2] * lon), 0, carta.shape[0] - 1).astype(int)

    # Classifica só o retângulo da carta usado pela grade (a carta inteira é grande).
    x0, x1, y0, y1 = px.min(), px.max() + 1, py.min(), py.max() + 1
    classes = classificar(carta[y0:y1, x0:x1])[py - y0, px - x0]
    # Filtro de moda 3×3: some com pixels soltos de números e símbolos.
    classes = ndimage.generic_filter(classes, lambda v: np.bincount(v.astype(int), minlength=5).argmax(), size=3)
    # Dentro do quadro, a terra é a do jogo (polígono do cenário), para o fundo
    # encontrar a praia na linha da costa; terra da carta fora do polígono vira areia
    # rasa da intermarés. Fora do quadro vale a carta.
    scenario = json.loads(SCENARIO.read_text(encoding="utf-8"))
    quadro = scenario["bounds_m"]
    dentro = (gx >= quadro["min_x"]) & (gx <= quadro["max_x"]) & (gz >= quadro["min_z"]) & (gz <= quadro["max_z"])
    mascara_terra = Image.new("L", (len(xs), len(zs)), 0)
    ImageDraw.Draw(mascara_terra).polygon(
        [((x - GRADE["min_x"]) / CELULA_M - 0.5, (z - GRADE["min_z"]) / CELULA_M - 0.5) for x, z in scenario["land_polygon_m"]], fill=1)
    terra_jogo = np.asarray(mascara_terra).astype(bool) & dentro
    classes[(classes == TERRA) & ~terra_jogo & dentro] = INTERMARES
    classes[terra_jogo] = TERRA

    def distancia(mascara: np.ndarray) -> np.ndarray:
        if not mascara.any():
            return np.full(mascara.shape, np.inf)
        return ndimage.distance_transform_edt(~mascara) * CELULA_M

    # Profundidade abaixo do nível de redução (negativa = acima dele).
    reducao = np.zeros(classes.shape)
    d_terra = distancia(classes == TERRA)
    reducao[classes == TERRA] = -(PREAMAR_M + 0.3)

    mascara = classes == INTERMARES
    d_fora = distancia(classes >= RASO)
    t = d_terra / np.maximum(d_terra + d_fora, 1e-6)
    planicie = ALTURA_PLANICIE_M * (1.0 - t)
    face = np.clip(1.0 - d_terra / FACE_PRAIA_M, 0.0, 1.0)
    reducao[mascara] = -(planicie + (PREAMAR_M - planicie) * face)[mascara]

    for faixa, (raso, fundo) in FAIXAS.items():
        mascara = classes == faixa
        d_raso = distancia(classes < faixa)
        d_fundo = distancia(classes > faixa)
        # Entre as duas curvas, pela posição relativa; numa planície larga, longe da
        # vizinha funda, a rampa a partir da costa leva ao meio da faixa (sondagens de
        # 2,5 a 4,5 m no raso a nordeste). As duas se combinam sem degrau.
        entre = d_raso / np.maximum(d_raso + d_fundo, 1e-6)
        rampa = RASO_RAMPA_PESO * (1.0 - np.exp(-d_raso / RASO_RAMPA_M))
        t = 1.0 - (1.0 - entre) * (1.0 - rampa)
        reducao[mascara] = (raso + (fundo - raso) * t)[mascara]

    mascara = classes == FUNDO
    d_raso = distancia(classes < FUNDO)
    reducao[mascara] = (10.0 + FUNDO_EXTRA_M * (1.0 - np.exp(-d_raso / (FUNDO_RAMPA_M * FUNDO_EXTRA_M))))[mascara]

    reducao = ndimage.gaussian_filter(reducao, sigma=1.2)
    lamina = reducao + PREAMAR_M
    terra = classes == TERRA
    lamina[terra_jogo] = LAMINA_SOB_TERRA_M
    # Relevo do continente fora do quadro: altitude dos pontos do KML (inverso do
    # quadrado da distância), subindo a partir da costa da carta.
    amostras = [(f["coordinates_m"][0], f["source_altitude_m"]) for f in json.loads(GEOMETRY.read_text(encoding="utf-8"))["features"]
                if f["kind"] == "poi" and "source_altitude_m" in f]
    peso_total = np.zeros(gx.shape)
    soma = np.zeros(gx.shape)
    for (px_m, pz_m), altitude in amostras:
        peso = 1.0 / np.maximum((gx - px_m) ** 2 + (gz - pz_m) ** 2, 1e-6)
        peso_total += peso
        soma += peso * altitude
    d_costa = ndimage.distance_transform_edt(terra) * CELULA_M
    t = np.clip(d_costa / FAIXA_COSTEIRA_M, 0.0, 1.0)
    relevo = np.maximum(soma / peso_total * t * t * (3.0 - 2.0 * t), 0.4)
    fora = terra & ~dentro
    lamina[fora] = -relevo[fora]
    elevacao = np.clip(-lamina, ELEVACAO_MIN_M, ELEVACAO_MAX_M)
    normalizada = ((elevacao - ELEVACAO_MIN_M) / (ELEVACAO_MAX_M - ELEVACAO_MIN_M)).astype("<f2")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(normalizada.tobytes())

    scenario["bathymetry"] = {
        "data": OUTPUT_RES,
        "size": [len(xs), len(zs)],
        "bounds_m": GRADE,
        "cell_m": CELULA_M,
        "elevation_min_m": ELEVACAO_MIN_M,
        "elevation_max_m": ELEVACAO_MAX_M,
        "high_tide_m": PREAMAR_M,
        "source": "DHN carta náutica 1108 (Baía de Todos os Santos — Porto de São Roque e proximidades, 1:15.000); lâmina d'água na preamar de sizígia",
    }
    SCENARIO.write_text(json.dumps(scenario, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    contagem = {nome: int((classes == k).sum()) for k, nome in enumerate(["terra", "intermares", "0-5", "5-10", ">10"])}
    print(f"{OUTPUT.name}: {len(xs)}×{len(zs)} células de {CELULA_M:g} m · {contagem}")
    print(f"relevo fora do quadro: até {relevo[fora].max():.0f} m")
    agua = lamina[~terra]
    print(f"lâmina d'água na preamar: {agua.min():.1f} a {agua.max():.1f} m (média {agua.mean():.1f} m)")


if __name__ == "__main__":
    main()
