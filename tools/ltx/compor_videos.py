"""Monta os vídeos da edição Tripothon a partir dos clipes do LTX.

- carregamento_sobrevoo: bg1 -> bg2 -> bg3 com fusões de 1 s e a emenda do fim no
  começo fundida também, para o laço não ter corte (a tela de carregamento repete).
- cinematica_abertura: c1 ... c5 com fusões de 1 s, entrando do preto e saindo nele.

Para cada um sai um .mp4 (H.264 1080p, para o site) e um .ogv (Theora 720p, que é o
que o VideoStreamPlayer do Godot lê), sem áudio, e um pôster .jpg do primeiro quadro.

Uso: python compor_videos.py <pasta_dos_clipes> <pasta_de_saida>
"""
import json
import os
import subprocess
import sys

FFMPEG = r"C:\Program Files\ffmpeg\bin\ffmpeg.exe"
FFPROBE = r"C:\Program Files\ffmpeg\bin\ffprobe.exe"
FUSAO = 1.0
# setpts antes do fps: depois dele o setpts deixa a taxa de quadros indefinida, e o
# xfade exige taxa constante.
NORMA = "setpts=PTS-STARTPTS,scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,fps=24,format=yuv420p"


def duracao(arquivo):
    saida = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "json", arquivo],
                           capture_output=True, text=True, check=True).stdout
    return float(json.loads(saida)["format"]["duration"])


def cadeia_de_fusoes(n, duracoes):
    """[0][1]... -> [s], com xfade de FUSAO entre cada par. Devolve (filtro, duração)."""
    partes = [f"[{i}:v]{NORMA}[v{i}]" for i in range(n)]
    atual = "v0"
    total = duracoes[0]
    for i in range(1, n):
        saida = f"x{i}" if i < n - 1 else "s"
        partes.append(f"[{atual}][v{i}]xfade=transition=fade:duration={FUSAO}:offset={total - FUSAO:.3f}[{saida}]")
        total = total + duracoes[i] - FUSAO
        atual = saida
    if n == 1:
        partes.append("[v0]null[s]")
    return partes, total


def gravar(filtro, entradas, rotulo, destino_base):
    comando = [FFMPEG, "-y", "-loglevel", "error"]
    for e in entradas:
        comando += ["-i", e]
    mp4 = destino_base + ".mp4"
    ogv = destino_base + ".ogv"
    poster = destino_base + "_poster.jpg"
    subprocess.run(comando + ["-filter_complex", ";".join(filtro), "-map", f"[{rotulo}]", "-an",
                              "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
                              "-movflags", "+faststart", mp4], check=True)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", mp4, "-an", "-vf", "scale=1280:720",
                    "-c:v", "libtheora", "-q:v", "6", "-g", "24", ogv], check=True)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", mp4, "-frames:v", "1", "-q:v", "3", poster], check=True)
    return mp4, ogv


def main():
    clipes, saida = sys.argv[1], sys.argv[2]
    os.makedirs(saida, exist_ok=True)
    feitos = {}

    fundo = [os.path.join(clipes, f"bg{i}.mp4") for i in (1, 2, 3)]
    fundo = [f for f in fundo if os.path.exists(f)]
    if fundo:
        d = [duracao(f) for f in fundo]
        filtro, total = cadeia_de_fusoes(len(fundo), d)
        # A emenda do laço: o corpo (de 1 s ao fim) funde no fim com o primeiro segundo;
        # o último quadro vira o quadro de 1 s, que é onde o laço recomeça.
        # O trim perde a taxa de quadros, e o xfade exige taxa constante: fps=24 de novo.
        filtro += ["[s]split[s1][s2]", f"[s1]trim=start={FUSAO},setpts=PTS-STARTPTS,fps=24[corpo]",
                   f"[s2]trim=end={FUSAO},setpts=PTS-STARTPTS,fps=24[cabeca]",
                   f"[corpo][cabeca]xfade=transition=fade:duration={FUSAO}:offset={total - 2 * FUSAO:.3f}[laco]"]
        feitos["carregamento_sobrevoo"] = gravar(filtro, fundo, "laco", os.path.join(saida, "carregamento_sobrevoo"))

    cine = [os.path.join(clipes, f"c{i}.mp4") for i in (1, 2, 3, 4, 5)]
    cine = [f for f in cine if os.path.exists(f)]
    if cine:
        d = [duracao(f) for f in cine]
        filtro, total = cadeia_de_fusoes(len(cine), d)
        filtro += [f"[s]fade=t=in:st=0:d=1.2,fade=t=out:st={total - 1.6:.3f}:d=1.5[cine]"]
        feitos["cinematica_abertura"] = gravar(filtro, cine, "cine", os.path.join(saida, "cinematica_abertura"))

    for nome, (mp4, ogv) in feitos.items():
        print(f"{nome}: {duracao(mp4):.1f} s, mp4 {os.path.getsize(mp4) / 1048576:.1f} MB, ogv {os.path.getsize(ogv) / 1048576:.1f} MB")


if __name__ == "__main__":
    main()
