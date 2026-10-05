import json
import sys

caminho = sys.argv[1]
partes = sys.argv[2].split(",") if len(sys.argv) > 2 else ["config", "censo", "vistas", "ab", "horas", "passeio", "gpu"]
with open(caminho, encoding="utf-8") as f:
    r = json.load(f)


def titulo(t):
    print("\n" + "=" * 8 + " " + t + " " + "=" * 8)


def milhar(n):
    return f"{int(n):,}".replace(",", ".")


if "config" in partes and "config" in r:
    titulo("CONFIG")
    c = r["config"]
    for k, v in c.items():
        if k in ("ambiente", "camera", "subviewports"):
            continue
        print(f"  {k}: {v}")
    print("  ambiente:", json.dumps(c.get("ambiente", {}), ensure_ascii=False))
    print("  camera:", c.get("camera"))
    print("  subviewports:")
    for s in c.get("subviewports", []):
        print("    ", json.dumps(s, ensure_ascii=False))
    for k in ("montagem_ms", "jogo_pronto_ms", "estabilizado_ms", "relogio", "avisos"):
        print(f"  {k}: {r.get(k)}")

if "censo" in partes and "censo" in r:
    titulo("CENSO")
    c = r["censo"]
    for k in ("nos", "malhas_distintas", "mesh_instances_visiveis", "mesh_instances_com_sombra", "mesh_instances_com_visibility_range",
              "mesh_instances_com_skin", "tri_em_mesh_instances", "tri_em_mesh_instances_com_skin", "esqueletos", "ossos",
              "animation_players", "animation_players_tocando", "faces_trimesh", "areas_monitorando", "label3d", "audio_tocando",
              "controles", "controles_visiveis"):
        print(f"  {k}: {milhar(c[k]) if isinstance(c[k], (int, float)) else c[k]}")
    print("  formas_de_colisao:", c["formas_de_colisao"])
    print("  corpos:", c["corpos"])
    print("  monitores:", c["monitores"])
    classes = sorted(c["por_classe"].items(), key=lambda kv: -kv[1])
    print("  por_classe (top 40):", ", ".join(f"{k}={v}" for k, v in classes[:40]))
    print("  process por script:")
    for k, v in sorted(c["process_por_script"].items(), key=lambda kv: -kv[1]):
        print(f"     {v:5d}  {k}")
    print("  physics por script:")
    for k, v in sorted(c["physics_por_script"].items(), key=lambda kv: -kv[1]):
        print(f"     {v:5d}  {k}")
    print("  interno por classe:", c["interno_por_classe"])
    titulo("LUZES")
    for l in c["luzes"]:
        print("  ", json.dumps(l, ensure_ascii=False))
    titulo("MAIORES MALHAS (tri x instancias)")
    for m in c["maiores_malhas"][:40]:
        print(f"  {milhar(m['tri_total']):>12} = {milhar(m['tri']):>9} x {m['instancias']:<4} {m['exemplo'][-110:]}")
    titulo("LODs DAS MAIORES")
    for m in c.get("lods_das_maiores", []):
        print(f"  niveis={m['niveis_lod']}  tri={milhar(m['tri']):>9}  {m['exemplo'][-100:]}")
    titulo("GLB INSTANCIADOS (catalogo)")
    tot = 0
    for g in c["glb_instanciados"]:
        tot += g["tri_total"]
    print(f"  total tri (soma tri x instancias): {milhar(tot)}  em {sum(g['instancias'] for g in c['glb_instanciados'])} instancias de {len(c['glb_instanciados'])} chaves")
    for g in c["glb_instanciados"][:60]:
        print(f"  {milhar(g['tri_total']):>12} = {milhar(g['tri']):>9} x {g['instancias']:<4} {g['chave']}")
    titulo("MULTIMESH POR GRUPO")
    grupos = sorted(c["multimesh_por_grupo"].items(), key=lambda kv: -kv[1]["tri_lod0"])
    tot_i = sum(g["instancias"] for _, g in grupos)
    tot_t = sum(g["tri_lod0"] for _, g in grupos)
    print(f"  total: {milhar(tot_i)} instancias, {milhar(tot_t)} tri LOD0, {sum(g['blocos'] for _, g in grupos)} blocos")
    for k, g in grupos:
        print(f"  {milhar(g['tri_lod0']):>13} tri | {g['instancias']:>6} inst x {g['tri_por_instancia']:>6} | {g['blocos']:>4} blocos | vis {g['vis_begin']:.0f}-{g['vis_end']:.0f} | lod_bias {g['lod_bias']:.2f} | lods {g.get('niveis_lod')} | sup {g.get('superficies')} | sombra {g['sombra']} | {g.get('material')} transp={g.get('transparencia')} cull={g.get('cull')} | {k}")
    titulo("CANVAS LAYERS")
    for cl in c["canvas_layers"]:
        print("  ", json.dumps(cl, ensure_ascii=False))

if "vistas" in partes and r.get("vistas"):
    titulo("VISTAS (fps | quadro ms | gpu | cpu-rs | sub gpu | proc | fis scripts | fis srv | passos | cauda | draws | tri)")
    for v in r["vistas"]:
        print(f"  {v['lugar']:<18} {v['rumo_graus']:>3}  {v['fps']:>6.1f} fps  {v['quadro_ms']:>7.1f} ms  p95 {v['p95_ms']:>7.1f} max {v['max_ms']:>7.1f} | gpu {v['rs_gpu_ms']:>6.1f}  cpu {v['rs_cpu_ms']:>5.1f}  subgpu {v['sub_gpu_ms']:>5.2f} | proc {v['process_scripts_ms']:>6.2f}  fis {v['fisica_scripts_ms']:>7.2f}  srv {v['fisica_servidor_ms']:>6.2f}  x{v['fisica_passos_por_quadro']:>4.1f}  cauda {v['cauda_ms']:>6.1f} | {v['draws']:>5} draws  {milhar(v['primitivas']):>11} tri  {v['objetos']:>5} obj {'PAUSADO' if v.get('pausado') else ''}")
    fps = sorted(v["fps"] for v in r["vistas"])
    print(f"  => {len(fps)} vistas: min {fps[0]}  mediana {fps[len(fps)//2]}  max {fps[-1]}")

def linha_base(rotulo, b):
    if not b:
        return
    print(f"  {rotulo}: {b.get('fps')} fps  {b.get('quadro_ms')} ms | gpu {b.get('rs_gpu_ms')} subgpu {b.get('sub_gpu_ms')} cpu-rs {b.get('rs_cpu_ms')} | proc {b.get('process_scripts_ms')} fis {b.get('fisica_scripts_ms')} srv {b.get('fisica_servidor_ms')} x{b.get('fisica_passos_por_quadro')} cauda {b.get('cauda_ms')} | draws {b.get('draws')} tri {b.get('primitivas')}")


for chave_ab in ("ab", "ab_cpu", "ab_gpu"):
    if "ab" not in partes or not r.get(chave_ab):
        continue
    titulo("A/B %s  (vista: %s)" % (chave_ab, json.dumps(r.get(chave_ab + "_vista"), ensure_ascii=False)))
    linha_base("como jogado ", r.get(chave_ab + "_como_jogado"))
    linha_base("base inicial", r.get(chave_ab + "_base_inicial"))
    linha_base("base final  ", r.get(chave_ab + "_base_final"))
    ordem = sorted(r[chave_ab], key=lambda a: -a["ganho_ms"]) if "--ordem" not in sys.argv else r[chave_ab]
    for a in ordem:
        c = a["com"]
        ba = a["base_antes"]
        bd = a["base_depois"]
        gpu_b = (ba["rs_gpu_ms"] + bd["rs_gpu_ms"]) / 2
        proc_b = (ba["process_scripts_ms"] + bd["process_scripts_ms"]) / 2
        fis_b = (ba["fisica_scripts_ms"] + bd["fisica_scripts_ms"]) / 2
        pas_b = (ba["fisica_passos_por_quadro"] + bd["fisica_passos_por_quadro"]) / 2
        tri_b = (ba["primitivas"] + bd["primitivas"]) / 2
        drw_b = (ba["draws"] + bd["draws"]) / 2
        print(f"  {a['ganho_ms']:>+8.2f} ms | {a['fps_base']:>5.1f}->{a['fps_com']:>5.1f} fps | gpu {gpu_b:>5.1f}->{c['rs_gpu_ms']:>5.1f} | proc {proc_b:>5.2f}->{c['process_scripts_ms']:>5.2f} | fis {fis_b:>6.2f}->{c['fisica_scripts_ms']:>6.2f} x{pas_b:.1f}->{c['fisica_passos_por_quadro']:.1f} | tri {tri_b/1e6:>5.2f}M->{c['primitivas']/1e6:>5.2f}M | draws {drw_b:>5.0f}->{c['draws']:>5} | n={a['n']:<5} {a['nome']}")

if "horas" in partes and r.get("horas"):
    titulo("HORAS")
    for h in r["horas"]:
        print(f"  {h['hora']:>4}h  {h['fps']:>6.1f} fps  gpu {h['rs_gpu_ms']:>6.1f}  proc {h['process_scripts_ms']:.2f}  fis {h['fisica_scripts_ms']:.2f} x{h['fisica_passos_por_quadro']}  luzes {h['luzes_locais_acesas']}  tri {milhar(h['primitivas'])} draws {h['draws']}")
    j = r.get("como_o_jogador_ve")
    if j:
        print(f"  COM V-SYNC: {j['fps']} fps  mediana {j['mediana_ms']} ms  p95 {j['p95_ms']} ms  max {j['max_ms']} ms")

if "passeio" in partes and r.get("passeio"):
    titulo("PASSEIO")
    p = dict(r["passeio"])
    p.pop("serie_ms", None)
    print("  ", json.dumps(p, ensure_ascii=False))

if "gpu" in partes and r.get("gpu"):
    titulo("GPU (nvidia-smi: usada MiB, total, uso %, temp, W, clock)")
    for g in r["gpu"]:
        print(f"  {g['quando']:<22} t={g['ms']/1000:>6.0f}s  {g['linha']}  | godot video {g['godot_video_mb']} MB (tex {g['godot_texturas_mb']}, buf {g['godot_buffers_mb']})")
