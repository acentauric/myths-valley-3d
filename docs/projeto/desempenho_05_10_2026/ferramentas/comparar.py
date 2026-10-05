import json
import statistics
import sys

base_p = sys.argv[1]
outros = sys.argv[2:]


def carregar(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def por_lugar(r):
    d = {}
    for v in r["vistas"]:
        d.setdefault(v["lugar"], []).append(v)
    return d


def tick(v):
    return v["fisica_scripts_ms"] / max(v["fisica_passos_por_quadro"], 0.01)


base = carregar(base_p)
bl = por_lugar(base)
rs = [(p, carregar(p)) for p in outros]

print("### Geral (todas as vistas em comum)")
print("| conjunto | vistas | FPS min | FPS mediana | FPS max | quadro mediano (ms) | GPU mediana (ms) | tri mediana (M) | fisica ms/tick mediana | passos/quadro mediana | montagem (s) |")
print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")


def linha(nome, r, chaves):
    vs = [v for v in r["vistas"] if (v["lugar"], v["rumo_graus"]) in chaves]
    fps = sorted(v["fps"] for v in vs)
    print("| %s | %d | %.1f | %.1f | %.1f | %.1f | %.1f | %.2f | %.2f | %.2f | %.1f |" % (
        nome, len(vs), fps[0], statistics.median(fps), fps[-1], statistics.median(v["quadro_ms"] for v in vs),
        statistics.median(v["rs_gpu_ms"] for v in vs), statistics.median(v["primitivas"] for v in vs) / 1e6,
        statistics.median(tick(v) for v in vs), statistics.median(v["fisica_passos_por_quadro"] for v in vs), r.get("montagem_ms", 0) / 1000.0))


for p, r in rs:
    chaves = set((v["lugar"], v["rumo_graus"]) for v in r["vistas"]) & set((v["lugar"], v["rumo_graus"]) for v in base["vistas"])
    linha("hoje (%s)" % base_p.split("\\")[-1], base, chaves)
    linha("%s  aplicar=%s patch=%s" % (p.split("\\")[-1], ",".join(r.get("aplicado", [])), r.get("patch_costa")), r, chaves)

for p, r in rs:
    rl = por_lugar(r)
    print()
    print("### Por lugar: hoje -> %s" % p.split("\\")[-1])
    print("| lugar | FPS pior | FPS mediana | FPS melhor | GPU ms (pior vista) | tri M (pior vista) | fisica ms/tick (mediana) |")
    print("|---|---|---|---|---|---|---|")
    for lugar in bl:
        if lugar not in rl:
            continue
        a = bl[lugar]
        b = rl[lugar]
        fa = sorted(v["fps"] for v in a)
        fb = sorted(v["fps"] for v in b)
        pa = min(a, key=lambda v: v["fps"])
        pb = min(b, key=lambda v: v["fps"])
        print("| %s | %.1f -> **%.1f** | %.1f -> **%.1f** | %.1f -> **%.1f** | %.0f -> %.0f | %.1f -> %.1f | %.1f -> %.1f |" % (
            lugar, fa[0], fb[0], statistics.median(fa), statistics.median(fb), fa[-1], fb[-1], pa["rs_gpu_ms"], pb["rs_gpu_ms"],
            pa["primitivas"] / 1e6, pb["primitivas"] / 1e6, statistics.median(tick(v) for v in a), statistics.median(tick(v) for v in b)))
