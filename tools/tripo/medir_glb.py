"""Mede os GLBs do catálogo sem abrir o Godot: caixa envolvente (x, y, z), faces e
imagens embutidas, lendo só o JSON do glTF. Serve para escolher a medida de
normalização em catalogo_assets.gd (altura ou largura) e conferir orientação.
Uso: python medir_glb.py [pasta_assets]"""
import json, os, re, struct, sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CAT = os.path.join(RAIZ, "prototipo_3d", "scripts", "prototipo_3d", "catalogo_assets.gd")
ASSETS = os.path.join(RAIZ, "prototipo_3d", "assets", "prototipo_3d")


def gltf_json(caminho):
    with open(caminho, "rb") as f:
        magic, version, length = struct.unpack("<4sII", f.read(12))
        chunk_len, chunk_type = struct.unpack("<II", f.read(8))
        return json.loads(f.read(chunk_len).decode("utf-8"))


def medir(caminho):
    g = gltf_json(caminho)
    lo = [1e9] * 3
    hi = [-1e9] * 3
    faces = 0
    for mesh in g.get("meshes", []):
        for prim in mesh.get("primitives", []):
            acc = g["accessors"][prim["attributes"]["POSITION"]]
            for i in range(3):
                lo[i] = min(lo[i], acc["min"][i])
                hi[i] = max(hi[i], acc["max"][i])
            if "indices" in prim:
                faces += g["accessors"][prim["indices"]]["count"] // 3
            else:
                faces += acc["count"] // 3
    size = [hi[i] - lo[i] for i in range(3)]
    return size, lo, faces, len(g.get("images", [])), len(g.get("nodes", []))


def main():
    cat = dict(re.findall(r'"([a-z_]+)":\s*\{"tripo":\s*"([^"]+)"', open(CAT, encoding="utf-8").read()))
    print(f"{'chave':22s} {'x':>7s} {'y':>7s} {'z':>7s} {'faces':>7s} img nós  base_y")
    for chave, rel in cat.items():
        caminho = os.path.join(ASSETS, rel)
        if not os.path.exists(caminho):
            print(f"{chave:22s} (ausente)")
            continue
        try:
            size, lo, faces, imgs, nos = medir(caminho)
            print(f"{chave:22s} {size[0]:7.2f} {size[1]:7.2f} {size[2]:7.2f} {faces:7d} {imgs:3d} {nos:3d} {lo[1]:7.2f}")
        except Exception as e:
            print(f"{chave:22s} erro: {e}")


if __name__ == "__main__":
    main()
