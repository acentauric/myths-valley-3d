"""Monta o teaser sobre a faixa narrada: tomadas cortadas nos tempos de tools/teaser/plano.json,
fusões centradas no corte, legendas de tools/teaser/legendas.ass e o cartão final.

As tomadas do jogo saem do diretor (tools/teaser/diretor.gd), em PNG, uma pasta por tomada;
com --versao ltx, cada tomada que tem clipe do LTX (tools/ltx/gerar-teaser.ps1) usa o clipe
no lugar, e a que não tem continua a do jogo.

Uso (da raiz do projeto):
  python tools/teaser/montar.py --audio teaser.mp3 --quadros <pasta das tomadas> saida.mp4
      [--versao ltx --clipes .assets-raw/ltx/teaser/clipes]

As legendas usam a Cormorant Garamond do jogo: o libass acha a fonte pelo fontconfig, então
instale assets/fonts/*.ttf no sistema (Linux: ~/.local/share/fonts e fc-cache) antes.
"""
import argparse
import json
import os
import subprocess
import tempfile

W, H, FPS = 1280, 720, 30
AQUI = os.path.dirname(os.path.abspath(__file__))
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
FONTES = "assets/fonts"
IDENTIDADE = "assets/prototipo_3d/identidade"


def cartao_final(destino):
    """Capa noturna escurecida, o logo e as linhas do jogo."""
    texto = lambda fonte, t, cor, tam, y: (f"drawtext=fontfile={FONTES}/{fonte}:text='{t}':fontcolor={cor}:"
                                          f"fontsize={tam}:x=(w-tw)/2:y={y}")
    filtro = ("[0]scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,eq=brightness=-0.16:saturation=0.85,"
              "gblur=sigma=1.2[b];[1]scale=760:-1[l];[b][l]overlay=(W-w)/2:(H-h)/2-50,"
              + ",".join([texto("Cinzel-Variavel.ttf", "BAHIA · 1887", "0xE9D7A6", 26, "h/2+90"),
                          texto("CormorantGaramond-Variavel.ttf", "A 3D life-sim adventure · Made with Tripo and Godot",
                                "0xEDEDED", 26, "h/2+134"),
                          texto("CormorantGaramond-Variavel.ttf", "mythsvalley.app.br", "0xC9C9C9", 22, "h-60")]))
    subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", f"{IDENTIDADE}/capa_noite.webp",
                    "-i", f"{IDENTIDADE}/logo_myths_valley.png", "-filter_complex", filtro, destino], check=True)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("saida")
    a.add_argument("--audio", required=True)
    a.add_argument("--quadros", required=True)
    a.add_argument("--clipes", default=".assets-raw/ltx/teaser/clipes")
    a.add_argument("--versao", choices=["jogo", "ltx"], default="jogo")
    o = a.parse_args()
    plano = json.load(open(os.path.join(AQUI, "plano.json"), encoding="utf-8"))
    tmp = tempfile.mkdtemp()
    cartao = os.path.join(tmp, "cartao_final.png")
    cartao_final(cartao)
    trocas = {"{quadros}": o.quadros, "{clipes}": o.clipes, "{cartao}": cartao}

    def resolver(caminho):
        for k, v in trocas.items():
            caminho = caminho.replace(k, v)
        return caminho

    tomadas, fim = plano["tomadas"], plano["fim"]
    args, filtros, duracoes, trans = [FFMPEG, "-y", "-loglevel", "error"], [], [], []
    for i, t in enumerate(tomadas):
        b = tomadas[i + 1]["corte"] if i + 1 < len(tomadas) else fim
        t_in = t.get("transicao", 0.04) if i > 0 else 0.0
        t_out = tomadas[i + 1].get("transicao", 0.04) if i + 1 < len(tomadas) else 0.0
        d = (b - t["corte"]) + t_in / 2 + t_out / 2
        duracoes.append(d)
        trans.append(t_in)
        ini = max(0.0, t.get("de", 0.0) - t_in / 2)
        fonte = resolver(t.get("fonte", ""))
        if o.versao == "ltx" and t.get("ltx") and os.path.exists(resolver(t["ltx"])):
            fonte = resolver(t["ltx"])
        if t.get("cor"):
            args += ["-f", "lavfi", "-t", f"{d:.3f}", "-i", f"color=c={t['cor']}:s={W}x{H}:r={FPS}"]
            f = f"[{i}:v]format=yuv420p"
        elif os.path.isdir(fonte):
            args += ["-framerate", str(FPS), "-start_number", str(int(round(ini * FPS))), "-i", os.path.join(fonte, "%04d.png")]
            f = f"[{i}:v]setpts=PTS-STARTPTS,scale={W}:{H}:flags=lanczos,fps={FPS},format=yuv420p"
        elif fonte.lower().endswith((".png", ".jpg", ".webp")):
            args += ["-loop", "1", "-t", f"{d:.3f}", "-i", fonte]
            n, z = int(d * FPS) + 1, t.get("zoom", 0.06)
            f = (f"[{i}:v]scale={W*2}:{H*2}:force_original_aspect_ratio=increase,crop={W*2}:{H*2},"
                 f"zoompan=z='1+{z}*on/{n}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={n}:s={W}x{H}:fps={FPS},format=yuv420p")
        else:
            args += ["-ss", f"{ini:.3f}", "-t", f"{d + 0.5:.3f}", "-i", fonte]
            f = (f"[{i}:v]setpts=PTS-STARTPTS,scale={W}:{H}:force_original_aspect_ratio=increase,"
                 f"crop={W}:{H},fps={FPS},format=yuv420p")
        filtros.append(f + f",trim=duration={d:.3f},setpts=PTS-STARTPTS,settb=AVTB[c{i}]")

    # As fusões: a saída acumulada cresce d - t a cada tomada, e cada fusão fica centrada no corte.
    atual, comprimento = "[c0]", duracoes[0]
    for i in range(1, len(tomadas)):
        t = trans[i]
        filtros.append(f"{atual}[c{i}]xfade=transition=fade:duration={t:.3f}:offset={comprimento - t:.3f}[x{i}]")
        atual, comprimento = f"[x{i}]", comprimento + duracoes[i] - t
    filtros.append(f"{atual}subtitles=tools/teaser/legendas.ass,trim=duration={fim:.3f}[v]")
    args += ["-i", o.audio, "-filter_complex", ";".join(filtros), "-map", "[v]", "-map", f"{len(tomadas)}:a",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "192k", "-t", f"{fim:.3f}", "-movflags", "+faststart", o.saida]
    subprocess.run(args, check=True)


if __name__ == "__main__":
    main()
