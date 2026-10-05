"""Corta a narração da travessia em um trecho por legenda, a partir do Whisper da OpenAI.

    $env:OPENAI_API_KEY = (Get-Chave 'OPENAI_API_KEY')   # tools/comum/chaves.ps1
    python tools/elevenlabs/alinhar_travessia.py

Lê a tomada inteira gerada por `gerar-travessia.ps1`, transcreve com tempo por palavra,
casa as palavras do Whisper com as das legendas ("travessia" em data/dialogos/pedro.json)
e corta no meio do silêncio entre uma legenda e a seguinte. Grava os trechos em
assets/audio/narracao/travessia/trecho_NN.mp3 e o registro dos tempos em
data/travessia_narracao.json. Imprime cada legenda ao lado do que o Whisper ouviu, para
conferir se o narrador leu tudo.
"""

import difflib
import json
import os
import re
import subprocess
import unicodedata
from pathlib import Path

from openai import OpenAI

RAIZ = Path(__file__).resolve().parents[2]
TOMADA = RAIZ / ".assets-raw/elevenlabs/travessia/narracao_completa.mp3"
PASTA = RAIZ / "assets/audio/narracao/travessia"
REGISTRO = RAIZ / "data/travessia_narracao.json"
# Folga antes da primeira palavra e depois da última (segundos).
FOLGA = 0.12


def normalizar(palavra: str) -> str:
    sem_acento = unicodedata.normalize("NFKD", palavra).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]", "", sem_acento.lower())


def palavras(texto: str) -> list[str]:
    return [n for n in (normalizar(p) for p in texto.split()) if n]


def duracao(arquivo: Path) -> float:
    saida = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(arquivo)],
                           capture_output=True, text=True, check=True)
    return float(saida.stdout.strip())


def main() -> None:
    legendas = json.loads((RAIZ / "data/dialogos/pedro.json").read_text(encoding="utf-8"))["travessia"]
    cliente = OpenAI()
    with TOMADA.open("rb") as arquivo:
        resposta = cliente.audio.transcriptions.create(
            model="whisper-1", file=arquivo, language="pt",
            response_format="verbose_json", timestamp_granularities=["word"])
    ouvidas = [(normalizar(w.word), w.start, w.end) for w in resposta.words if normalizar(w.word)]

    # Palavra do roteiro -> índice da legenda; o difflib casa as duas sequências.
    roteiro: list[str] = []
    dona: list[int] = []
    for indice, legenda in enumerate(legendas):
        for p in palavras(legenda):
            roteiro.append(p)
            dona.append(indice)
    casamento = difflib.SequenceMatcher(a=roteiro, b=[o[0] for o in ouvidas], autojunk=False)
    inicio = [None] * len(legendas)
    fim = [None] * len(legendas)
    ouvido_por_legenda: list[list[str]] = [[] for _ in legendas]
    for bloco in casamento.get_matching_blocks():
        for k in range(bloco.size):
            indice = dona[bloco.a + k]
            _, comeco, final = ouvidas[bloco.b + k]
            inicio[indice] = comeco if inicio[indice] is None else min(inicio[indice], comeco)
            fim[indice] = final if fim[indice] is None else max(fim[indice], final)
    for palavra, comeco, _ in ouvidas:
        # Para a conferência: cada palavra ouvida vai para a legenda em cujo intervalo cai.
        for indice in range(len(legendas)):
            if inicio[indice] is not None and inicio[indice] - 0.05 <= comeco <= fim[indice] + 0.05:
                ouvido_por_legenda[indice].append(palavra)
                break
    faltando = [i for i in range(len(legendas)) if inicio[i] is None]
    if faltando:
        raise SystemExit(f"Legendas sem palavras casadas no áudio: {faltando}. Gere a narração de novo.")

    total = duracao(TOMADA)
    cortes = [0.0]
    for i in range(len(legendas) - 1):
        cortes.append((fim[i] + inicio[i + 1]) / 2.0)
    cortes.append(total)

    PASTA.mkdir(parents=True, exist_ok=True)
    trechos = []
    for i in range(len(legendas)):
        comeco = max(0.0, cortes[i] if i else inicio[0] - FOLGA)
        final = min(total, cortes[i + 1] if i < len(legendas) - 1 else fim[i] + 0.6)
        destino = PASTA / f"trecho_{i + 1:02d}.mp3"
        fade = max(0.0, final - comeco - 0.08)
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", f"{comeco:.3f}", "-to", f"{final:.3f}", "-i", str(TOMADA),
                        "-af", f"afade=t=in:d=0.03,afade=t=out:st={fade:.3f}:d=0.08",
                        "-c:a", "libmp3lame", "-q:a", "2", str(destino)], check=True)
        trechos.append({"arquivo": destino.name, "inicio": round(comeco, 3), "fim": round(final, 3),
                        "duracao": round(final - comeco, 3)})
        print(f"{i + 1:02d} {comeco:6.2f}-{final:6.2f}s  {legendas[i]}")
        print(f"         ouvido: {' '.join(ouvido_por_legenda[i])}")

    REGISTRO.write_text(json.dumps({
        "fonte": "ElevenLabs Eleven v3, voz BDM · Nelson Silvestre · Narrador; cortes pelo Whisper (whisper-1)",
        "duracao_total": round(total, 3),
        "trechos": trechos,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(trechos)} trechos em {PASTA}")


if __name__ == "__main__":
    main()
