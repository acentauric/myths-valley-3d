"""Inicia as máscaras artísticas do terreno a partir do estudo HTML do mapa.

Esta conversão é separada de importar_kml.py: costa, mata ampla e vila foram
interpretadas de capturas e podem ser revistas sem alterar o KML original.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

from importar_kml import PROJECT


HTML = PROJECT.parent / "MAPA_PONTOS_INTERESSE.html"
REGION = PROJECT / "data/mapas/bom_jesus_dos_pobres.json"
OUTPUT = PROJECT / "data/mapas/bom_jesus_dos_pobres_cenario.json"
TOKEN = re.compile(r"[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")

# Transformação visual do HTML (51 graus) preservada para a conversão inversa.
HTML_ORIGIN_LON = -38.79088960724624
HTML_NORTH_LAT = -12.80046679346458
HTML_EAST_DEGREE = 108535.0
HTML_SOUTH_DEGREE = 111320.0
COS_51 = 0.62932039
SIN_51 = 0.77714596
HTML_SCALE = 0.61493


def extract_path(html: str, name: str) -> str:
    match = re.search(r'<path id="' + re.escape(name) + r'" d="([^"]+)"', html)
    if not match:
        raise ValueError(f"Caminho {name} não encontrado no HTML")
    return match.group(1)


def sample_path(description: str, interval_px: float = 12.0) -> list[tuple[float, float]]:
    values = TOKEN.findall(description)
    points: list[tuple[float, float]] = []
    current = (0.0, 0.0)
    first = current
    command = ""
    i = 0

    def add_line(end: tuple[float, float]) -> None:
        nonlocal current
        steps = max(1, math.ceil(math.dist(current, end) / interval_px))
        start = current
        for step in range(1, steps + 1):
            fraction = step / steps
            points.append((start[0] + (end[0] - start[0]) * fraction, start[1] + (end[1] - start[1]) * fraction))
        current = end

    while i < len(values):
        if values[i].isalpha():
            command = values[i]
            i += 1
            if command == "Z":
                add_line(first)
                continue
        if command == "M":
            current = (float(values[i]), float(values[i + 1]))
            first = current
            points.append(current)
            i += 2
            command = "L"
        elif command == "L":
            add_line((float(values[i]), float(values[i + 1])))
            i += 2
        elif command == "H":
            add_line((float(values[i]), current[1]))
            i += 1
        elif command == "V":
            add_line((current[0], float(values[i])))
            i += 1
        elif command == "C":
            start = current
            a = (float(values[i]), float(values[i + 1]))
            b = (float(values[i + 2]), float(values[i + 3]))
            end = (float(values[i + 4]), float(values[i + 5]))
            length = math.dist(start, a) + math.dist(a, b) + math.dist(b, end)
            steps = max(2, math.ceil(length / interval_px))
            for step in range(1, steps + 1):
                t = step / steps
                u = 1 - t
                points.append((
                    u**3 * start[0] + 3 * u * u * t * a[0] + 3 * u * t * t * b[0] + t**3 * end[0],
                    u**3 * start[1] + 3 * u * u * t * a[1] + 3 * u * t * t * b[1] + t**3 * end[1],
                ))
            current = end
            i += 6
        else:
            raise ValueError(f"Comando SVG não suportado: {command}")
    if len(points) > 1 and math.dist(points[0], points[-1]) < 1e-6:
        points.pop()
    return points


def svg_to_meters(point: tuple[float, float], projection: dict) -> tuple[float, float]:
    screen_x, screen_y = point
    rotated_x = (screen_x - 70.0) / HTML_SCALE - 1083.073629
    rotated_y = (screen_y - 79.0) / HTML_SCALE + 352.070896
    east = COS_51 * rotated_x + SIN_51 * rotated_y
    south = -SIN_51 * rotated_x + COS_51 * rotated_y
    lon = HTML_ORIGIN_LON + east / HTML_EAST_DEGREE
    lat = HTML_NORTH_LAT - south / HTML_SOUTH_DEGREE
    x = (lon - projection["origin_lon"]) * projection["meters_per_degree_lon"]
    z = (projection["origin_lat"] - lat) * projection["meters_per_degree_lat"]
    return x, z


def clip_polygon(points: list[tuple[float, float]], bounds: dict) -> list[tuple[float, float]]:
    clipped = points
    for axis, value, greater in (
        (0, bounds["min_x"], True),
        (0, bounds["max_x"], False),
        (1, bounds["min_z"], True),
        (1, bounds["max_z"], False),
    ):
        result = []
        if not clipped:
            break
        previous = clipped[-1]
        previous_inside = previous[axis] >= value if greater else previous[axis] <= value
        for current in clipped:
            current_inside = current[axis] >= value if greater else current[axis] <= value
            if current_inside != previous_inside:
                denominator = current[axis] - previous[axis]
                fraction = (value - previous[axis]) / denominator
                other = 1 - axis
                intersection = [0.0, 0.0]
                intersection[axis] = value
                intersection[other] = previous[other] + (current[other] - previous[other]) * fraction
                result.append(tuple(intersection))
            if current_inside:
                result.append(current)
            previous, previous_inside = current, current_inside
        clipped = result
    return clipped


def round_points(points: list[tuple[float, float]]) -> list[list[float]]:
    return [[round(x, 2), round(z, 2)] for x, z in points]


def convert(html_file: Path, region_file: Path, output: Path, margin: float) -> None:
    html = html_file.read_text(encoding="utf-8")
    region = json.loads(region_file.read_text(encoding="utf-8"))
    base_bounds = region["bounds_m"]
    bounds = {key: round(value + (-margin if key.startswith("min") else margin), 2) for key, value in base_bounds.items()}
    projection = region["projection"]
    curves = {}
    for name in ("landShape", "coastline", "northForest", "villageShape"):
        curves[name] = [svg_to_meters(point, projection) for point in sample_path(extract_path(html, name))]
    result = {
        "schema_version": 1,
        "region_id": region["region_id"],
        "provenance": "Contornos interpretados das capturas no MAPA_PONTOS_INTERESSE.html; não constam do KML.",
        "units": "meters",
        "background_kind": "sea",
        "bounds_m": bounds,
        "land_polygon_m": round_points(clip_polygon(curves["landShape"], bounds)),
        "coastline_m": round_points(curves["coastline"]),
        "forest_polygon_m": round_points(clip_polygon(curves["northForest"], bounds)),
        "village_polygon_m": round_points(clip_polygon(curves["villageShape"], bounds)),
        "vegetation": {"seed": 1887, "tree_count": 1800, "clearing_m": 8.0},
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Máscaras curadas -> {output} ({len(result['land_polygon_m'])} vértices de terreno)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", type=Path, default=HTML)
    parser.add_argument("--region", type=Path, default=REGION)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--margin", type=float, default=180.0)
    args = parser.parse_args()
    convert(args.html, args.region, args.output, args.margin)


if __name__ == "__main__":
    main()
