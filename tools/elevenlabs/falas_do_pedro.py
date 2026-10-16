"""As falas do Pedro nas missões dele que ainda não têm voz (10/10/2026: "existem muitas falas do
Pedro ainda sem narração; pode criar os áudios de todas as falas do Pedro").

    python -I tools/elevenlabs/falas_do_pedro.py listar <saida.json>
        lista o que falta: os passos com texto e "audio" vazio, as respostas que o Pedro dá
        ("meta.resposta" com "a_quem": "pedro") e os arremates que ele fala ("narra" não falso),
        nas filas em que ele é o dono (data/missoes_*.json, "dono": "pedro"). Cada item:
        {"arquivo", "tipo", "id", "audio", "texto"}; "texto" é o "tts" quando há.
    python -I tools/elevenlabs/falas_do_pedro.py gravar <lista.json>
        escreve o nome do áudio no JSON de cada item cujo mp3 já existe em assets/audio/vozes,
        mexendo só na linha da chave (o resto do arquivo fica como está).

Quem gera o áudio é o tools/elevenlabs/gerar-falas-pedro.ps1, que chama os dois.
"""
import glob
import json
import os
import re
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VOZES = os.path.join(RAIZ, "assets", "audio", "vozes")


def _tem(nome):
    return os.path.exists(os.path.join(VOZES, nome + ".mp3"))


def _letras_de_fabrica():
    """A letra de fábrica de cada atalho, lida da tabela DEFINICOES de scripts/prototipo_3d/atalhos.gd."""
    codigo = open(os.path.join(RAIZ, "scripts", "prototipo_3d", "atalhos.gd"), encoding="utf-8").read()
    return {m.group(1): m.group(2) for m in re.finditer(r'"(\w+)":\s*\{[^}]*"padrao":\s*KEY_([A-Z])', codigo)}


LETRAS = _letras_de_fabrica()


def _falado(texto):
    """O texto como a voz o diz: a tecla que o texto cita pela ação ({tecla:mochila}, #254) sai na letra de FÁBRICA
    do atalho. A voz é gerada uma vez, com as letras de fábrica; o que o jogador lê, no jogo, segue as teclas dele."""
    return re.sub(r"\{tecla:(\w+)\}", lambda m: LETRAS.get(m.group(1), m.group(1)), texto)


def listar():
    itens = []
    for caminho in sorted(glob.glob(os.path.join(RAIZ, "data", "missoes_*.json"))):
        dados = json.load(open(caminho, encoding="utf-8"))
        if dados.get("dono") != "pedro":
            continue
        base = os.path.basename(caminho)[len("missoes_"):-len(".json")]
        arquivo = os.path.relpath(caminho, RAIZ).replace("\\", "/")
        for passo in dados.get("passos", []):
            pid = str(passo.get("id", ""))
            texto = str(passo.get("tts") or passo.get("texto") or "")
            if texto and str(passo.get("audio", "")) == "" and "audio" in passo:
                itens.append({"arquivo": arquivo, "tipo": "passo", "id": pid, "audio": "pedro_%s_%s" % (base, pid), "texto": _falado(texto)})
            meta = passo.get("meta", {})
            if meta.get("resposta") and meta.get("a_quem") == "pedro" and not meta.get("audio_resposta"):
                itens.append({"arquivo": arquivo, "tipo": "resposta", "id": pid, "audio": "pedro_%s_%s_resposta" % (base, pid),
                              "texto": _falado(str(meta.get("tts_resposta") or meta["resposta"]))})
        arremate = dados.get("arremate") or {}
        if arremate.get("texto") and arremate.get("narra", True) is not False and not arremate.get("audio"):
            itens.append({"arquivo": arquivo, "tipo": "arremate", "id": "", "audio": "pedro_%s_arremate" % base,
                          "texto": _falado(str(arremate.get("tts") or arremate["texto"]))})
    return itens


def _gravar_um(texto, item):
    nome = item["audio"]
    if item["tipo"] == "passo":
        inicio = texto.index('"id": "%s"' % item["id"])
        fim = texto.find('"id": "', inicio + 1)
        fim = len(texto) if fim < 0 else fim
        posicao = texto.index('"audio": ""', inicio, fim)
        return texto[:posicao] + '"audio": "%s"' % nome + texto[posicao + len('"audio": ""'):]
    if item["tipo"] == "resposta":
        inicio = texto.index('"id": "%s"' % item["id"])
        posicao = texto.index('"resposta":', inicio)
        recuo = re.search(r"[ \t]*$", texto[:posicao]).group(0)
        return texto[:posicao] + '"audio_resposta": "%s",\n%s' % (nome, recuo) + texto[posicao:]
    inicio = texto.index('"arremate": {')
    fim_da_linha = texto.index("\n", inicio) + 1
    recuo = re.match(r"[ \t]*", texto[fim_da_linha:]).group(0)
    return texto[:fim_da_linha] + '%s"audio": "%s",\n' % (recuo, nome) + texto[fim_da_linha:]


def gravar(itens):
    por_arquivo = {}
    for item in itens:
        if _tem(item["audio"]):
            por_arquivo.setdefault(item["arquivo"], []).append(item)
    for arquivo, lista in por_arquivo.items():
        caminho = os.path.join(RAIZ, arquivo)
        texto = open(caminho, encoding="utf-8").read()
        for item in lista:
            texto = _gravar_um(texto, item)
        json.loads(texto)
        open(caminho, "w", encoding="utf-8", newline="\n").write(texto)
        print("%s: %d áudio(s)" % (arquivo, len(lista)))


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("listar", "gravar"):
        print(__doc__)
        sys.exit(2)
    if sys.argv[1] == "listar":
        lista = listar()
        json.dump(lista, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("%d fala(s) do Pedro sem voz" % len(lista))
    else:
        gravar(json.load(open(sys.argv[2], encoding="utf-8")))
