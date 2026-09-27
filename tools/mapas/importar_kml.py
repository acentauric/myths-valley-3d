"""Converte um KML de uma região para vetores locais em metros usados no Godot.

O KML original continua sendo a fonte. Execute este arquivo novamente quando ele mudar.
Somente a geometria explícita no KML entra no JSON gerado; costa e cobertura
vegetal inferidas de imagens pertencem ao arquivo de cenário curado da região.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = PROJECT / "data/mapas/bom_jesus_dos_pobres_fonte.kml"
DEFAULT_OUTPUT = PROJECT / "data/mapas/bom_jesus_dos_pobres.json"
NS = {"kml": "http://www.opengis.net/kml/2.2"}
# O quadro "Mapa" é o recorte do mundo jogável, sempre 16:9 (o desenhado à mão no
# Google Earth fica perto disso, nunca exato).
FRAME_ASPECT = 16.0 / 9.0


def meters_per_degree(latitude: float) -> tuple[float, float]:
    angle = math.radians(latitude)
    north = (
        111132.92
        - 559.82 * math.cos(2 * angle)
        + 1.175 * math.cos(4 * angle)
        - 0.0023 * math.cos(6 * angle)
    )
    east = 111412.84 * math.cos(angle) - 93.5 * math.cos(3 * angle) + 0.118 * math.cos(5 * angle)
    return east, north


def read_coordinates(element: ET.Element) -> list[tuple[float, float, float]]:
    coordinates = element.find(".//kml:coordinates", NS)
    if coordinates is None or not coordinates.text:
        raise ValueError("Geometria sem coordenadas KML")
    result = []
    for token in coordinates.text.split():
        values = token.split(",")
        if len(values) < 2:
            raise ValueError(f"Coordenada KML incompleta: {token}")
        result.append((float(values[0]), float(values[1]), float(values[2]) if len(values) > 2 else 0.0))
    return result


def slug(text: str) -> str:
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "_", plain.lower()).strip("_") or "sem_nome"


def convert(source: Path, output: Path, region_id: str, origin_name: str) -> None:
    original = source.read_bytes()
    root = ET.fromstring(original)
    placemarks = root.findall(".//kml:Placemark", NS)
    raw = []
    for index, placemark in enumerate(placemarks, start=1):
        name = placemark.findtext("kml:name", default=f"Local {index}", namespaces=NS)
        placemark_id = placemark.get("id", "").strip()
        element = None
        for tag, geometry in (("Point", "point"), ("LineString", "line"), ("Polygon", "polygon")):
            element = placemark.find(f"kml:{tag}", NS)
            if element is not None:
                break
        if element is None:
            continue
        coordinates = read_coordinates(element)
        if geometry == "polygon" and len(coordinates) > 1 and coordinates[0][:2] == coordinates[-1][:2]:
            coordinates.pop()
        kind = "area" if geometry == "polygon" else "river" if geometry == "line" and name.casefold() == "rio" else "road" if geometry == "line" else "poi"
        if geometry == "polygon" and name.casefold().strip() == "mapa":
            kind = "map_frame"
        for data in placemark.findall(".//kml:ExtendedData/kml:Data", NS):
            if data.get("name", "").casefold() == "kind":
                declared = (data.findtext("kml:value", default="", namespaces=NS) or "").strip().casefold()
                allowed = {"point": {"poi"}, "line": {"road", "river"}, "polygon": {"area", "map_frame"}}
                if declared not in allowed[geometry]:
                    raise ValueError(f"Tipo KML inválido para {name}: {declared}")
                kind = declared
        raw.append((index, placemark_id, name, geometry, kind, coordinates))
    if not raw:
        raise ValueError("Nenhuma geometria encontrada no KML")

    anchor = next(
        (coordinates[0] for _, _, name, geometry, _, coordinates in raw if geometry == "point" and name.casefold() == origin_name.casefold()),
        None,
    )
    if anchor is None:
        raise ValueError(f"Ponto de origem '{origin_name}' não encontrado no KML")
    origin_lon, origin_lat = anchor[:2]
    east_factor, north_factor = meters_per_degree(origin_lat)

    features = []
    feature_ids = set()
    xs = []
    zs = []
    for index, placemark_id, name, geometry, kind, coordinates in raw:
        projected = []
        geographical = []
        for lon, lat, _altitude in coordinates:
            x = (lon - origin_lon) * east_factor
            z = (origin_lat - lat) * north_factor
            projected.append([round(x, 3), round(z, 3)])
            geographical.append([lon, lat])
            xs.append(x)
            zs.append(z)
        feature_id = f"kml_{slug(placemark_id)}" if placemark_id else f"provisional_{kind}_{index:02d}_{slug(name)}"
        if feature_id in feature_ids:
            raise ValueError(f"Identificador KML duplicado: {feature_id}")
        feature_ids.add(feature_id)
        feature = {
            "id": feature_id,
            "name": name,
            "kind": kind,
            "geometry": geometry,
            "source_index": index,
            "source_placemark_id": placemark_id,
            "coordinates_m": projected,
            "coordinates_wgs84": geographical,
        }
        if geometry == "point":
            feature["source_altitude_m"] = round(coordinates[0][2], 3)
        if kind == "map_frame":
            normalize_frame(feature, origin_lon, origin_lat, east_factor, north_factor)
            xs.extend(point[0] for point in feature["coordinates_m"])
            zs.extend(point[1] for point in feature["coordinates_m"])
        features.append(feature)

    result = {
        "schema_version": 1,
        "region_id": region_id,
        "source_file": source.name,
        "source_sha256": hashlib.sha256(original).hexdigest(),
        "projection": {
            "type": "local_equirectangular",
            "origin_name": origin_name,
            "origin_lon": origin_lon,
            "origin_lat": origin_lat,
            "meters_per_degree_lon": east_factor,
            "meters_per_degree_lat": north_factor,
            "x_axis": "east",
            "z_axis": "south",
            "godot_unit": "meter",
        },
        "bounds_m": {
            "min_x": round(min(xs), 3),
            "max_x": round(max(xs), 3),
            "min_z": round(min(zs), 3),
            "max_z": round(max(zs), 3),
        },
        "features": features,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(features)} feições -> {output} ({round(max(xs)-min(xs))} × {round(max(zs)-min(zs))} m)")


def normalize_frame(feature: dict, origin_lon: float, origin_lat: float, east_factor: float, north_factor: float) -> None:
    """Troca o quadro desenhado pelo retângulo 16:9 alinhado aos eixos que o contém.

    A dimensão curta cresce, centrada; nada do desenho original fica de fora. As
    coordenadas desenhadas ficam em source_coordinates_m.
    """
    points = feature["coordinates_m"]
    min_x = min(p[0] for p in points)
    max_x = max(p[0] for p in points)
    min_z = min(p[1] for p in points)
    max_z = max(p[1] for p in points)
    width, height = max_x - min_x, max_z - min_z
    center_x, center_z = (min_x + max_x) / 2, (min_z + max_z) / 2
    if width / height < FRAME_ASPECT:
        width = height * FRAME_ASPECT
    else:
        height = width / FRAME_ASPECT
    corners = [
        (center_x - width / 2, center_z + height / 2),
        (center_x + width / 2, center_z + height / 2),
        (center_x + width / 2, center_z - height / 2),
        (center_x - width / 2, center_z - height / 2),
    ]
    feature["source_coordinates_m"] = points
    feature["coordinates_m"] = [[round(x, 3), round(z, 3)] for x, z in corners]
    feature["coordinates_wgs84"] = [[origin_lon + x / east_factor, origin_lat - z / north_factor] for x, z in corners]
    feature["aspect"] = "16:9"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--region-id", default="bom_jesus_dos_pobres")
    parser.add_argument("--origin-name", default="Praça")
    args = parser.parse_args()
    convert(args.source, args.output, args.region_id, args.origin_name)


if __name__ == "__main__":
    main()
