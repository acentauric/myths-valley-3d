"""Monta a introdução ("A travessia", #129) a partir dos clipes do LTX de gerar-introducao.ps1.

Cada trecho ocupa na linha do tempo o mesmo que a legenda dura no jogo (abertura.gd):
a duração do áudio do trecho mais o respiro de 0,8 s. O clipe é cortado nesse tempo
(ou estendido no último quadro, se for curto) e funde no seguinte em 0,8 s; o último
segue inteiro, até o saveiro chegar à igreja. Saem:

- PREVIA_introducao.mp4: com a narração em sequência, a trilha da travessia por baixo e a
  legenda em português queimada (só para revisão);
- introducao_jogo.mp4: a mesma montagem sem áudio e sem legenda;
- jogo/trecho_NN.ogv: um clipe por trecho em Theora 1280x720, sem áudio, que é o que o
  VideoStreamPlayer do Godot lê (a abertura toca um por legenda; Continuar troca o clipe).

O plano (texto, duração, qual tomada usar em "clipe") vem de introducao_plano.json.

Uso: python tools/ltx/compor_introducao.py [--sem-jogo]
"""
import json
import os
import subprocess
import sys
from pathlib import Path

FFMPEG = r"C:\Program Files\ffmpeg\bin\ffmpeg.exe"
FFPROBE = r"C:\Program Files\ffmpeg\bin\ffprobe.exe"
RAIZ = Path(__file__).resolve().parents[2]
PLANO = RAIZ / "tools/ltx/introducao_plano.json"
BASE = RAIZ / ".assets-raw/ltx/introducao"
CLIPES = BASE / "clipes"
NARRACAO = RAIZ / "assets/audio/narracao/travessia"
MUSICA = RAIZ / "assets/audio/musica/tema_travessia.mp3"
# O mesmo respiro da legenda no jogo (PAUSA_ENTRE_TRECHOS em abertura.gd).
PAUSA = 0.8
FUSAO = 0.8
# A trilha fica por baixo da voz, como no jogo (Audio.ABAFO_TRAVESSIA).
VOLUME_MUSICA = 0.22
NORMA = "setpts=PTS-STARTPTS,scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,fps=24,format=yuv420p"


def duracao(arquivo) -> float:
    saida = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "json", str(arquivo)],
                           capture_output=True, text=True, check=True).stdout
    return float(json.loads(saida)["format"]["duration"])


def tempo_srt(s: float) -> str:
    ms = int(round(s * 1000))
    return f"{ms // 3600000:02d}:{ms // 60000 % 60:02d}:{ms // 1000 % 60:02d},{ms % 1000:03d}"


def main() -> None:
    plano = json.loads(PLANO.read_text(encoding="utf-8"))
    trechos = plano["trechos"]
    n = len(trechos)
    clipes, audios, fatias, inicios = [], [], [], []
    t = 0.0
    for i, tr in enumerate(trechos):
        nome = tr.get("clipe", f"trecho_{int(tr['trecho']):02d}.mp4")
        clipe = CLIPES / nome
        audio = NARRACAO / f"trecho_{int(tr['trecho']):02d}.mp3"
        if not clipe.exists():
            sys.exit(f"Falta o clipe {clipe}")
        clipes.append(clipe)
        audios.append(audio)
        inicios.append(t)
        fala = duracao(audio)
        if i < n - 1:
            fatia = fala + PAUSA
            t += fatia
            fatias.append(fatia + FUSAO)
        else:
            # O último segue inteiro (o saveiro chegando), e nunca menos que a fala.
            fatias.append(max(duracao(clipe), fala + PAUSA))
            t += fatias[-1]
    total = t

    # Vídeo: cada clipe na sua fatia (o último quadro segura se o clipe for curto),
    # fundidos em FUSAO; entra do preto e sai nele.
    partes = []
    for i, f in enumerate(fatias):
        partes.append(f"[{i}:v]{NORMA},tpad=stop_mode=clone:stop_duration=3,trim=duration={f:.3f},setpts=PTS-STARTPTS,fps=24[v{i}]")
    atual, comprimento = "v0", fatias[0]
    for i in range(1, n):
        partes.append(f"[{atual}][v{i}]xfade=transition=fade:duration={FUSAO}:offset={comprimento - FUSAO:.3f}[x{i}]")
        comprimento += fatias[i] - FUSAO
        atual = f"x{i}"
    partes.append(f"[{atual}]fade=t=in:st=0:d=1.0,fade=t=out:st={total - 1.8:.3f}:d=1.8[video]")

    # Áudio: cada trecho no seu início, a trilha por baixo saindo junto com a imagem.
    # (Grafo separado: um filter_complex com saída sem uso não roda.)
    filtro_video = ";".join(partes)
    partes = []
    k = n
    for i, inicio in enumerate(inicios):
        atraso = int(round(inicio * 1000))
        partes.append(f"[{k + i}:a]aresample=48000,adelay={atraso}|{atraso}[a{i}]")
    partes.append(f"[{2 * n}:a]aresample=48000,volume={VOLUME_MUSICA},atrim=duration={total:.3f},"
                  f"afade=t=in:d=1.5,afade=t=out:st={total - 2.5:.3f}:d=2.5[musica]")
    rotulos = "".join(f"[a{i}]" for i in range(n))
    partes.append(f"{rotulos}[musica]amix=inputs={n + 1}:normalize=0:duration=longest,atrim=duration={total:.3f}[audio]")

    # Legenda de revisão (português), um bloco por trecho.
    srt = BASE / "previa.srt"
    blocos = []
    for i, tr in enumerate(trechos):
        fim = inicios[i + 1] if i + 1 < n else total
        blocos.append(f"{i + 1}\n{tempo_srt(inicios[i])} --> {tempo_srt(fim - 0.15)}\n{tr['texto']}\n")
    srt.write_text("\n".join(blocos), encoding="utf-8")

    entradas = []
    for c in clipes:
        entradas += ["-i", str(c)]
    for a in audios:
        entradas += ["-i", str(a)]
    entradas += ["-i", str(MUSICA)]
    filtro_audio = ";".join(partes)
    jogo = BASE / "introducao_jogo.mp4"
    # Base sem som e sem legenda; a prévia queima a legenda nela e soma o áudio.
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *entradas, "-filter_complex", filtro_video,
                    "-map", "[video]", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "19",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(jogo)], check=True)
    audio_mix = BASE / "previa_audio.m4a"
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *entradas, "-filter_complex", filtro_audio,
                    "-map", "[audio]", "-c:a", "aac", "-b:a", "192k", str(audio_mix)], check=True)
    estilo = ("FontName=Georgia,FontSize=17,Italic=1,PrimaryColour=&H00E8F0F4,OutlineColour=&H80000000,"
              "BorderStyle=1,Outline=1.2,Shadow=0.8,MarginV=38,MarginL=60,MarginR=60")
    previa = BASE / "PREVIA_introducao.mp4"
    # O filtro de legenda lê o caminho relativo à pasta de trabalho (sem os dois-pontos do C:).
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", str(jogo), "-i", str(audio_mix),
                    "-vf", f"subtitles=previa.srt:force_style='{estilo}'", "-map", "0:v", "-map", "1:a",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
                    "-c:a", "copy", "-shortest", "-movflags", "+faststart", str(previa)], check=True, cwd=BASE)
    print(f"prévia: {previa} ({duracao(previa):.1f} s, {previa.stat().st_size / 1048576:.1f} MB)")
    print(f"jogo (mp4): {jogo} ({jogo.stat().st_size / 1048576:.1f} MB)")
    for i, tr in enumerate(trechos):
        print(f"  trecho {tr['trecho']}: começa em {inicios[i]:.2f} s, fatia {fatias[i]:.2f} s ({clipes[i].name})")

    if "--sem-jogo" in sys.argv:
        return
    # Um .ogv por trecho para o jogo: o clipe inteiro (o jogo corta pela legenda), 720p.
    pasta_jogo = BASE / "jogo"
    pasta_jogo.mkdir(exist_ok=True)
    soma = 0
    for i, tr in enumerate(trechos):
        ogv = pasta_jogo / f"trecho_{int(tr['trecho']):02d}.ogv"
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", str(clipes[i]), "-an",
                        "-vf", "scale=1280:720,fps=24", "-c:v", "libtheora", "-q:v", "5", "-g", "24", str(ogv)],
                       check=True)
        soma += ogv.stat().st_size
    print(f"ogv do jogo: {pasta_jogo} ({soma / 1048576:.1f} MB nos {n})")


if __name__ == "__main__":
    main()
