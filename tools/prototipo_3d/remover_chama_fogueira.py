"""Retira a chama rígida do GLB da fogueira, preservando pedras, toras e textura.

O Tripo exportou tudo em uma malha. A chama ocupa o centro alto e usa os tons
quentes da textura; só seus triângulos são retirados da lista de índices.
Requer Pillow, já usada pelas ferramentas de materiais deste projeto.
"""

import io
import json
import math
import struct
from pathlib import Path

from PIL import Image


CAMINHO = Path(__file__).resolve().parents[2] / "assets/prototipo_3d/aderecos/fogueira_tripo.glb"


def main() -> None:
    raw = CAMINHO.read_bytes()
    assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 4)[0] == 2
    json_size = struct.unpack_from("<I", raw, 12)[0]
    document = json.loads(raw[20 : 20 + json_size])
    if document.get("extras", {}).get("chama_removida"):
        return
    binary_header = 20 + json_size
    assert raw[binary_header + 4 : binary_header + 8] == b"BIN\x00"
    binary_size = struct.unpack_from("<I", raw, binary_header)[0]
    binary = bytearray(raw[binary_header + 8 : binary_header + 8 + binary_size])
    accessors = document["accessors"]
    views = document["bufferViews"]
    primitive = document["meshes"][0]["primitives"][0]

    def accessor_values(index: int, format_char: str, components: int):
        accessor = accessors[index]
        view = views[accessor["bufferView"]]
        assert "byteStride" not in view
        offset = view["byteOffset"] + accessor.get("byteOffset", 0)
        size = struct.calcsize(format_char) * components
        return [
            struct.unpack_from("<" + format_char * components, binary, offset + i * size)
            for i in range(accessor["count"])
        ]

    positions = accessor_values(primitive["attributes"]["POSITION"], "f", 3)
    uv = accessor_values(primitive["attributes"]["TEXCOORD_0"], "f", 2)
    index_accessor = accessors[primitive["indices"]]
    assert index_accessor["componentType"] == 5123
    indices = [value[0] for value in accessor_values(primitive["indices"], "H", 1)]
    material = document["materials"][primitive["material"]]
    texture_index = material["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    image_index = document["textures"][texture_index]["source"]
    image_view = views[document["images"][image_index]["bufferView"]]
    start = image_view["byteOffset"]
    image = Image.open(io.BytesIO(binary[start : start + image_view["byteLength"]])).convert("RGB")
    colors = [
        image.getpixel(
            (
                max(0, min(image.width - 1, int(u * image.width))),
                max(0, min(image.height - 1, int(v * image.height))),
            )
        )
        for u, v in uv
    ]

    kept = []
    removed = 0
    for first in range(0, len(indices), 3):
        triangle = indices[first : first + 3]
        x = sum(positions[i][0] for i in triangle) / 3
        y = sum(positions[i][1] for i in triangle) / 3
        z = sum(positions[i][2] for i in triangle) / 3
        red, green, blue = (sum(colors[i][channel] for i in triangle) / 3 for channel in range(3))
        warm = red > 175 and green > 65 and blue < 95 and red > green * 1.4
        flame = math.hypot(x, z) < 0.28 and (y > 0.15 or (y > 0.045 and warm))
        if flame:
            removed += 1
        else:
            kept.extend(triangle)
    assert 1200 < removed < 1600, f"Geometria inesperada: {removed} faces da chama"
    index_view = views[index_accessor["bufferView"]]
    index_start = index_view["byteOffset"] + index_accessor.get("byteOffset", 0)
    struct.pack_into("<" + "H" * len(kept), binary, index_start, *kept)
    index_accessor["count"] = len(kept)
    document.setdefault("extras", {})["chama_removida"] = True

    encoded = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    output = bytearray(b"glTF" + struct.pack("<II", 2, 0))
    output += struct.pack("<I4s", len(encoded), b"JSON") + encoded
    output += struct.pack("<I4s", len(binary), b"BIN\x00") + binary
    struct.pack_into("<I", output, 8, len(output))
    temporary = CAMINHO.with_suffix(".glb.tmp")
    temporary.write_bytes(output)
    temporary.replace(CAMINHO)
    print(f"Fogueira: {removed} triângulos da chama removidos; {len(kept) // 3} preservados.")


if __name__ == "__main__":
    main()
