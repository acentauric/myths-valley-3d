"""DESCONTINUADO (26/09/2026): use a Retopologia (Malha Smart) do próprio Tripo Studio.
Ver docs/ASSETS_TRIPO.md. Mantido só como registro.

Reduz a malha de um GLB do Tripo por agrupamento de vértices, preservando UVs e texturas.

Os modelos HD do Tripo chegam com ~1,9 milhão de triângulos. Para adereços de
cenário, agrupar vértices numa grade (vertex clustering) leva a malha a poucas
dezenas de milhares de triângulos sem depender de ferramentas externas: só
`numpy`. As texturas embutidas, materiais e nós são copiados sem alteração.

    python prototipo_3d/tools/modelos/reduzir_glb.py entrada.glb saida.glb --celulas 140

`--celulas` é o número de células da grade no maior eixo do modelo (mais
células = mais detalhe). 120–160 fica entre 40 e 120 mil triângulos.
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

import numpy as np

COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path: Path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF", "não é um GLB"
    offset = 12
    gltf = None
    binary = b""
    while offset < length:
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + chunk_length]
        if chunk_type == 0x4E4F534A:
            gltf = json.loads(chunk.decode("utf-8"))
        elif chunk_type == 0x004E4942:
            binary = chunk
        offset += 8 + chunk_length
    return gltf, binary


def write_glb(path: Path, gltf: dict, binary: bytes) -> None:
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    binary += b"\0" * ((4 - len(binary) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(binary)
    with path.open("wb") as handle:
        handle.write(struct.pack("<4sII", b"glTF", 2, total))
        handle.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        handle.write(json_bytes)
        handle.write(struct.pack("<II", len(binary), 0x004E4942))
        handle.write(binary)


def read_accessor(gltf: dict, binary: bytes, index: int) -> np.ndarray:
    accessor = gltf["accessors"][index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    dtype = COMPONENT[accessor["componentType"]]
    count = COUNT[accessor["type"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", 0)
    item = np.dtype(dtype).itemsize * count
    if stride and stride != item:
        raw = np.frombuffer(binary, dtype=np.uint8, count=stride * accessor["count"], offset=start)
        raw = raw.reshape(accessor["count"], stride)[:, :item].copy()
        return raw.view(dtype).reshape(accessor["count"], count)
    return np.frombuffer(binary, dtype=dtype, count=accessor["count"] * count, offset=start).reshape(accessor["count"], count)


class Writer:
    def __init__(self, gltf: dict, existing: bytes):
        self.gltf = gltf
        self.parts = [existing]
        self.size = len(existing)

    def add(self, array: np.ndarray, target: int, accessor_type: str, component: int, minmax: bool = False) -> int:
        array = np.ascontiguousarray(array)
        payload = array.tobytes()
        padding = (4 - self.size % 4) % 4
        if padding:
            self.parts.append(b"\0" * padding)
            self.size += padding
        view_index = len(self.gltf["bufferViews"])
        self.gltf["bufferViews"].append({"buffer": 0, "byteOffset": self.size, "byteLength": len(payload), "target": target})
        self.parts.append(payload)
        self.size += len(payload)
        accessor = {"bufferView": view_index, "componentType": component, "count": int(array.shape[0]), "type": accessor_type}
        if minmax:
            accessor["min"] = array.min(axis=0).tolist()
            accessor["max"] = array.max(axis=0).tolist()
        self.gltf["accessors"].append(accessor)
        return len(self.gltf["accessors"]) - 1

    def bytes(self) -> bytes:
        return b"".join(self.parts)


def cluster_primitive(gltf: dict, binary: bytes, writer: Writer, primitive: dict, cells: int, cell_size: float | None) -> tuple[int, int]:
    positions = read_accessor(gltf, binary, primitive["attributes"]["POSITION"]).astype(np.float64)
    indices = read_accessor(gltf, binary, primitive["indices"]).astype(np.int64).reshape(-1)
    normals = read_accessor(gltf, binary, primitive["attributes"]["NORMAL"]).astype(np.float64) if "NORMAL" in primitive["attributes"] else None
    uvs = read_accessor(gltf, binary, primitive["attributes"]["TEXCOORD_0"]).astype(np.float64) if "TEXCOORD_0" in primitive["attributes"] else None
    low = positions.min(axis=0)
    span = (positions.max(axis=0) - low).max()
    size = cell_size if cell_size else span / cells
    keys = np.floor((positions - low) / size).astype(np.int64)
    # 1) A posição é decidida só pela célula espacial: vértices de ilhas de UV diferentes
    #    no mesmo lugar ganham exatamente a mesma posição, e a costura não abre (sem trincas).
    _, spatial_ids = np.unique(keys, axis=0, return_inverse=True)
    spatial_ids = spatial_ids.reshape(-1)
    spatial_count = int(spatial_ids.max()) + 1
    counts = np.bincount(spatial_ids, minlength=spatial_count).astype(np.float64)
    spatial_positions = np.zeros((spatial_count, 3))
    np.add.at(spatial_positions, spatial_ids, positions)
    spatial_positions /= counts[:, None]
    # 2) A identidade do vértice separa UVs distintas dentro da célula (grade fina de 1/256,
    #    ~8 px numa textura 2K), para a textura não "escorrer" para fora da ilha.
    if uvs is not None:
        uv_keys = np.floor(uvs * 256.0).astype(np.int64)
        combined = np.concatenate([spatial_ids[:, None], uv_keys], axis=1)
    else:
        combined = spatial_ids[:, None]
    _, first_index, cluster_ids = np.unique(combined, axis=0, return_index=True, return_inverse=True)
    cluster_ids = cluster_ids.reshape(-1)
    cluster_count = int(cluster_ids.max()) + 1
    cluster_spatial = spatial_ids[first_index]
    # Triângulos que colapsam no espaço somem; os demais são deduplicados.
    spatial_tris = spatial_ids[indices].reshape(-1, 3)
    valid = (spatial_tris[:, 0] != spatial_tris[:, 1]) & (spatial_tris[:, 1] != spatial_tris[:, 2]) & (spatial_tris[:, 0] != spatial_tris[:, 2])
    tris = cluster_ids[indices].reshape(-1, 3)[valid]
    sorted_tris = np.sort(tris, axis=1)
    _, unique_rows = np.unique(sorted_tris, axis=0, return_index=True)
    tris = tris[np.sort(unique_rows)]
    used = np.unique(tris)
    remap = -np.ones(cluster_count, dtype=np.int64)
    remap[used] = np.arange(used.size)
    tris = remap[tris]
    new_positions = spatial_positions[cluster_spatial[used]]
    attributes = {"POSITION": writer.add(new_positions.astype(np.float32), 34962, "VEC3", 5126, minmax=True)}
    if normals is not None:
        spatial_normals = np.zeros((spatial_count, 3))
        np.add.at(spatial_normals, spatial_ids, normals)
        new_normals = spatial_normals[cluster_spatial[used]]
        lengths = np.linalg.norm(new_normals, axis=1, keepdims=True)
        lengths[lengths == 0] = 1.0
        attributes["NORMAL"] = writer.add((new_normals / lengths).astype(np.float32), 34962, "VEC3", 5126)
    if uvs is not None:
        uv_sum = np.zeros((cluster_count, 2))
        np.add.at(uv_sum, cluster_ids, uvs)
        uv_count = np.bincount(cluster_ids, minlength=cluster_count).astype(np.float64)
        mean_uvs = uv_sum / uv_count[:, None]
        attributes["TEXCOORD_0"] = writer.add(mean_uvs[used].astype(np.float32), 34962, "VEC2", 5126)
    index_dtype = np.uint16 if used.size < 65535 else np.uint32
    component = 5123 if index_dtype is np.uint16 else 5125
    indices_accessor = writer.add(tris.reshape(-1).astype(index_dtype), 34963, "SCALAR", component)
    primitive["attributes"] = attributes
    primitive["indices"] = indices_accessor
    primitive.pop("targets", None)
    return int(indices.size // 3), int(tris.shape[0])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("entrada", type=Path)
    parser.add_argument("saida", type=Path)
    parser.add_argument("--celulas", type=int, default=140, help="células da grade no maior eixo")
    parser.add_argument("--celula-m", type=float, default=None, help="tamanho fixo da célula em unidades do modelo")
    args = parser.parse_args()
    gltf, binary = read_glb(args.entrada)
    if gltf.get("skins") or gltf.get("animations"):
        raise SystemExit("Este redutor cobre apenas malhas estáticas (sem skins ou animações).")
    # O buffer novo começa vazio: só as imagens embutidas e a geometria reduzida entram.
    source = dict(gltf)
    source_views = gltf["bufferViews"]
    gltf["bufferViews"] = []
    gltf["accessors"] = []
    writer = Writer(gltf, b"")
    for image in gltf.get("images", []):
        if "bufferView" not in image:
            continue
        view = source_views[image["bufferView"]]
        start = view.get("byteOffset", 0)
        payload = np.frombuffer(binary, dtype=np.uint8, count=view["byteLength"], offset=start)
        padding = (4 - writer.size % 4) % 4
        if padding:
            writer.parts.append(b"\0" * padding)
            writer.size += padding
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": writer.size, "byteLength": int(view["byteLength"])})
        writer.parts.append(payload.tobytes())
        writer.size += int(view["byteLength"])
        image["bufferView"] = len(gltf["bufferViews"]) - 1
    reader = {"accessors": source["accessors"], "bufferViews": source_views}
    before_total = after_total = 0
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if "indices" not in primitive or primitive.get("mode", 4) != 4:
                continue
            before, after = cluster_primitive(reader, binary, writer, primitive, args.celulas, args.celula_m)
            before_total += before
            after_total += after
    new_binary = writer.bytes()
    gltf["buffers"] = [{"byteLength": len(new_binary)}]
    write_glb(args.saida, gltf, new_binary)
    print(f"{args.entrada.name}: {before_total:,} -> {after_total:,} triângulos; {args.saida.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
