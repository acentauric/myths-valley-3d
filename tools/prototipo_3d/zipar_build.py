#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Zipa a pasta da build SEM extras e confere o zip contra o atualizador, antes de publicar (#231).

    python tools/prototipo_3d/zipar_build.py build/windows build/MythsValley3D-v0.12.0-build12-windows.zip
    python tools/prototipo_3d/zipar_build.py --conferir build/MythsValley3D-v0.12.0-build12-windows.zip

POR QUE ESTE SCRIPT E NÃO `tar -a -c`. O atualizador (scripts/autoload/atualizacao.gd) confere o zip
antes de extrair e recusa o que não conhece. O zip da Build 11 saiu do tar.exe do Windows com os extras
0x5455 + 0x7875 (carimbos e dono Unix), e o atualizador da própria 11 só deixa passar 0x5455 e 0x000a:
quem tem a 11 baixaria 1,2 GB para ouvir "pacote com nome ou conteúdo não permitido". Aqui o zip sai
como o das Builds 8 a 10: um arquivo por entrada, deflate, sem comentário, sem ZIP64, sem descritor e SEM
NENHUM EXTRA, que passa em qualquer atualizador desde a Build 9.

O QUE ELE CONFERE. O zip pronto passa por uma cópia em Python do `Atualizacao.conferir_zip` contra:

  1. todo atualizador de build anterior que ENXERGA este zip (data/atualizador_builds.json guarda, de cada
     build fechada, os limites e os extras que o atualizador dela aceita; quem tem a build N baixa a mais
     nova publicada, seja a N+1 ou a N+5, e confere o zip com a regra da N). Hoje é a Build 11;
  2. o código desta árvore (os extras de EXTRAS_ACEITOS e os limites de MAX_ZIP e MAX_EXTRAIDO).

Recusado em qualquer um, o script sai com 1 e não deixa o zip no destino. Essa cópia é conferida contra o
`Atualizacao.conferir_zip` de verdade pelo teste de unidade tests/unidade/test_zip_do_atualizador.gd, e
`conferir_fechamento_de_build.ps1` roda também o GDScript num Godot sem janela.

SAÍDA: 0 tudo certo, 1 algum atualizador recusaria o zip, 2 uso errado ou arquivo que não abre.
"""

import argparse
import json
import re
import shutil
import struct
import sys
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
NOME_DO_EXE = "MythsValley3D.exe"
# O que o `_conteudo_permitido` do atualizador deixa entrar no zip (na raiz ou dentro de MythsValley3D/).
NOMES_PERMITIDOS = (NOME_DO_EXE, "README.txt", "README_WINDOWS.txt", "README.md", "LEIA-ME.txt")
# A regra de extras que as Builds 9, 10 e 11 levam embutida (a 11 recusa o 0x7875 do tar.exe).
EXTRAS_ATE_A_BUILD_11 = (0x5455, 0x000A)
MAX_NOME = 180


@dataclass(frozen=True)
class Regra:
    """O que um atualizador aceita no formato do zip."""

    nome: str
    extras: tuple
    max_zip: int
    max_extraido: int
    max_entradas: int = 16

    def descricao(self) -> str:
        return "%s (extras %s)" % (self.nome, ", ".join("0x%04x" % i for i in self.extras) or "nenhum")


# --- a cópia do Atualizacao.conferir_zip --------------------------------------------------------------------------


def u16(b: bytes, i: int) -> int:
    return struct.unpack_from("<H", b, i)[0]


def u32(b: bytes, i: int) -> int:
    return struct.unpack_from("<I", b, i)[0]


def nome_seguro(nome: str) -> bool:
    """`Atualizacao.nome_seguro`: caminho relativo, sem nome reservado do Windows nem pontos soltos."""
    if not nome or len(nome) > MAX_NOME or nome.startswith("/") or "\\" in nome or ":" in nome:
        return False
    if any(ord(c) < 32 or ord(c) == 127 for c in nome):
        return False
    sem_barra = nome[:-1] if nome.endswith("/") else nome
    for parte in sem_barra.split("/"):
        if parte in ("", ".", "..") or parte.endswith(".") or parte.endswith(" "):
            return False
        base = parte.split(".")[0].upper()
        if base in ("CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"):
            return False
        if len(base) == 4 and base[:3] in ("COM", "LPT") and base[3] in "123456789¹²³":
            return False
    return True


def conteudo_permitido(nome: str) -> bool:
    """`Atualizacao._conteudo_permitido`."""
    if nome == "MythsValley3D/":
        return True
    relativo = nome[len("MythsValley3D/"):] if nome.startswith("MythsValley3D/") else nome
    return relativo in NOMES_PERMITIDOS


def extra_coerente(id_: int, dados: bytes) -> bool:
    """`Atualizacao._extra_coerente`: o conteúdo tem o tamanho e a forma que o formato do extra manda."""
    n = len(dados)
    if id_ == 0x5455:  # carimbos "UT": bits + um inteiro de 4 bytes por carimbo
        return 1 <= n <= 13 and (n - 1) % 4 == 0 and (dados[0] & 0xF8) == 0
    if id_ == 0x7875:  # dono "ux": versão 1, tamanho + uid, tamanho + gid
        if n == 0:
            return True
        if n < 3 or dados[0] != 1:
            return False
        tamanho_uid = dados[1]
        if tamanho_uid < 1 or tamanho_uid > 8 or n < 3 + tamanho_uid:
            return False
        tamanho_gid = dados[2 + tamanho_uid]
        return 1 <= tamanho_gid <= 8 and n == 3 + tamanho_uid + tamanho_gid
    if id_ == 0x000A:  # NTFS: 4 reservados e, se houver, o atributo 1 de 24 bytes
        return n == 4 or (n == 32 and u16(dados, 4) == 1 and u16(dados, 6) == 24)
    return False


def extras_seguros(extra: bytes, regra: Regra) -> str:
    """`Atualizacao._extras_seguros`. "" se passa; senão, o que o recusa."""
    i = 0
    vistos = set()
    while i < len(extra):
        if i + 4 > len(extra):
            return "extra truncado"
        id_ = u16(extra, i)
        tamanho = u16(extra, i + 2)
        if id_ not in regra.extras:
            return "extra 0x%04x fora dos que o atualizador aceita" % id_
        if id_ in vistos:
            return "extra 0x%04x repetido" % id_
        if i + 4 + tamanho > len(extra):
            return "extra 0x%04x passa do fim do campo" % id_
        if not extra_coerente(id_, extra[i + 4:i + 4 + tamanho]):
            return "extra 0x%04x com tamanho ou forma errados" % id_
        vistos.add(id_)
        i += 4 + tamanho
    return ""


def conferir_zip(caminho, regra: Regra) -> str:
    """`Atualizacao.conferir_zip`: "" se o atualizador que tem `regra` aceita o zip; senão, o motivo."""
    try:
        with open(caminho, "rb") as f:
            return _conferir_aberto(f, regra)
    except (OSError, struct.error):
        return "pacote inexistente ou grande demais"


def _conferir_aberto(f, regra: Regra) -> str:
    f.seek(0, 2)
    comprimento = f.tell()
    if comprimento < 22 or comprimento > regra.max_zip:
        return "pacote inexistente ou grande demais"
    inicio = max(0, comprimento - 65557)
    f.seek(inicio)
    cauda = f.read(comprimento - inicio)
    fim = -1
    for i in range(len(cauda) - 22, -1, -1):
        if u32(cauda, i) == 0x06054B50 and i + 22 + u16(cauda, i + 20) == len(cauda):
            fim = i
            break
    if fim < 0 or u16(cauda, fim + 4) != 0 or u16(cauda, fim + 6) != 0:
        return "índice ZIP inválido"
    quantidade = u16(cauda, fim + 10)
    tamanho_indice = u32(cauda, fim + 12)
    indice = u32(cauda, fim + 16)
    if (quantidade < 1 or quantidade > regra.max_entradas or quantidade != u16(cauda, fim + 8)
            or tamanho_indice > 65536 or indice + tamanho_indice != inicio + fim):
        return "índice ZIP fora dos limites"
    vistos = set()
    total = 0
    executaveis = 0
    intervalos = []
    f.seek(indice)
    for _ in range(quantidade):
        h = f.read(46)
        if len(h) != 46 or u32(h, 0) != 0x02014B50:
            return "entrada ZIP inválida"
        flags = u16(h, 8)
        metodo = u16(h, 10)
        comprimido = u32(h, 20)
        expandido = u32(h, 24)
        tamanho_nome = u16(h, 28)
        tamanho_extra = u16(h, 30)
        tamanho_comentario = u16(h, 32)
        atributos = u32(h, 38)
        modo = (atributos >> 16) & 0xF000
        local = u32(h, 42)
        if (flags & 1 or metodo not in (0, 8) or u16(h, 34) != 0 or modo not in (0, 0x8000, 0x4000)
                or atributos & 0x400 or local >= indice or comprimido > regra.max_zip or expandido > regra.max_extraido):
            return "pacote com link, criptografia ou tamanho inválido"
        nome_bytes = f.read(tamanho_nome)
        extra = f.read(tamanho_extra)
        f.read(tamanho_comentario)
        proxima = f.tell()
        try:
            nome = nome_bytes.decode("utf-8")
        except UnicodeDecodeError:
            return "pacote com nome ou conteúdo não permitido (nome que não é UTF-8)"
        problema = ""
        if not nome_seguro(nome):
            problema = "nome %r" % nome
        elif nome.lower() in vistos:
            problema = "nome repetido %r" % nome
        elif not conteudo_permitido(nome):
            problema = "arquivo %r que o pacote não pode ter" % nome
        else:
            motivo = extras_seguros(extra, regra)
            if motivo:
                problema = "%s no índice central de %r" % (motivo, nome)
        if problema:
            return "pacote com nome ou conteúdo não permitido (%s)" % problema
        vistos.add(nome.lower())
        if nome.split("/")[-1] == NOME_DO_EXE:
            executaveis += 1
        elif not nome.endswith("/") and expandido > 1048576:
            return "instruções do pacote grandes demais"
        total += expandido
        if total > regra.max_extraido:
            return "pacote expandido grande demais"
        f.seek(local)
        cabecalho = f.read(30)
        if len(cabecalho) != 30 or u32(cabecalho, 0) != 0x04034B50 or u16(cabecalho, 6) != flags or u16(cabecalho, 8) != metodo:
            return "cabeçalho local não confere"
        nome_local = f.read(u16(cabecalho, 26))
        extra_local = f.read(u16(cabecalho, 28))
        if nome_local != nome_bytes or f.tell() + comprimido > indice:
            return "caminho ou dados locais não conferem"
        motivo = extras_seguros(extra_local, regra)
        if motivo:
            return "caminho ou dados locais não conferem (%s no cabeçalho local de %r)" % (motivo, nome)
        if not flags & 8 and (u32(cabecalho, 18) != comprimido or u32(cabecalho, 22) != expandido):
            return "tamanhos locais não conferem"
        fim_local = f.tell() + comprimido
        if flags & 8:
            f.seek(fim_local)
            descritor = f.read(16)
            if len(descritor) < 12:
                return "descritor ZIP incompleto"
            deslocamento = 4 if u32(descritor, 0) == 0x08074B50 else 0
            if (u32(descritor, deslocamento) != u32(h, 16) or u32(descritor, deslocamento + 4) != comprimido
                    or u32(descritor, deslocamento + 8) != expandido):
                return "descritor ZIP não confere"
            fim_local += 12 + deslocamento
        intervalos.append((local, fim_local))
        f.seek(proxima)
    if f.tell() != indice + tamanho_indice or executaveis != 1:
        return "o pacote precisa conter um único MythsValley3D.exe"
    intervalos.sort()
    coberto = 0
    for comeco, termino in intervalos:
        if comeco != coberto or termino > indice:
            return "registros ZIP sobrepostos ou fora do índice"
        coberto = termino
    if coberto != indice:
        return "dados ZIP não declarados no índice"
    return ""


def resumo_do_zip(caminho) -> list:
    """Cada entrada do índice: (nome, bytes expandidos, ids dos extras). Para mostrar e para saber o tamanho do exe.
    Zip torto devolve [] e deixa `conferir_zip` dizer o que há de errado."""
    entradas = []
    try:
        with open(caminho, "rb") as f:
            f.seek(0, 2)
            inicio = max(0, f.tell() - 65557)
            f.seek(inicio)
            cauda = f.read()
            fim = next(i for i in range(len(cauda) - 22, -1, -1) if u32(cauda, i) == 0x06054B50)
            quantidade = u16(cauda, fim + 10)
            f.seek(u32(cauda, fim + 16))
            for _ in range(quantidade):
                h = f.read(46)
                nome = f.read(u16(h, 28)).decode("utf-8", "replace")
                extra = f.read(u16(h, 30))
                f.read(u16(h, 32))
                ids = []
                i = 0
                while i + 4 <= len(extra):
                    ids.append(u16(extra, i))
                    i += 4 + u16(extra, i + 2)
                entradas.append((nome, u32(h, 24), ids))
    except (OSError, struct.error, StopIteration):
        return []
    return entradas


# --- as regras: o código desta árvore e as builds que já estão na mão dos jogadores -----------------------------------


def _numero(texto: str) -> int:
    """`4 * 1024 * 1024 * 1024`, `16` ou `0x5455`: o produto dos fatores."""
    produto = 1
    for fator in texto.split("*"):
        produto *= int(fator.strip(), 0)
    return produto


def regra_do_codigo(raiz: Path = RAIZ) -> Regra:
    """A regra do `Atualizacao.conferir_zip` desta árvore, lida das constantes de scripts/autoload/atualizacao.gd."""
    codigo = (raiz / "scripts/autoload/atualizacao.gd").read_text(encoding="utf-8")

    def constante(nome: str) -> str:
        achou = re.search(r"^const %s\s*:=\s*(.+?)\s*$" % re.escape(nome), codigo, re.M)
        if not achou:
            raise SystemExit("não achei %s em scripts/autoload/atualizacao.gd" % nome)
        return achou.group(1)

    lista = constante("EXTRAS_ACEITOS").strip("[]")
    return Regra(
        "Atualizador do código desta árvore",
        tuple(int(i.strip(), 0) for i in lista.split(",") if i.strip()),
        _numero(constante("MAX_ZIP")),
        _numero(constante("MAX_EXTRAIDO")),
        _numero(constante("MAX_ENTRADAS")),
    )


def build_do_historico(raiz: Path = RAIZ) -> int:
    return int(json.loads((raiz / "data/historico_3d.json").read_text(encoding="utf-8"))["build_numero"])


def regras_das_builds_anteriores(zip_bytes: int, exe_bytes: int, build: int, atual: Regra, raiz: Path = RAIZ):
    """Uma regra por build anterior registrada. Devolve (as que enxergam o zip, as que não)."""
    registro = json.loads((raiz / "data/atualizador_builds.json").read_text(encoding="utf-8"))["builds"]
    enxergam, nao_enxergam = [], []
    for numero in sorted(registro, key=int):
        if int(numero) >= build:
            continue
        dados = registro[numero]
        extras = tuple(int(i, 0) for i in dados.get("extras_aceitos", [])) or EXTRAS_ATE_A_BUILD_11
        # O formato é o do código desta árvore (os nomes, a estrutura e os limites de entradas não mudaram desde a
        # Build 9); o que muda de build para build são os extras. O tamanho é outra conferência (quem não enxerga
        # o zip por causa dos limites nem tenta baixar).
        regra = Regra("Atualizador da Build %s" % numero, extras, atual.max_zip, atual.max_extraido, atual.max_entradas)
        if int(dados.get("max_zip", 0)) >= zip_bytes and int(dados.get("max_extraido", 0)) >= exe_bytes:
            enxergam.append(regra)
        else:
            nao_enxergam.append((regra, dados))
    return enxergam, nao_enxergam


# --- zipar -------------------------------------------------------------------------------------------------------------


def em_gb(n: int) -> str:
    return "%.2f GB" % (n / 1073741824) if n >= 1073741824 else "%d MB" % -(-n // 1048576)


def zipar(pasta: Path, destino: Path, build: int = None) -> int:
    """Zipa os arquivos da pasta (sem subpastas) em `destino`, sem extras, e o confere. Devolve quantos atualizadores
    o recusariam (0: o zip está em `destino`). SystemExit(msg) se a pasta não serve."""
    if not pasta.is_dir():
        raise SystemExit("a pasta da build não existe: %s" % pasta)
    itens = sorted(pasta.iterdir(), key=lambda p: p.name)
    estranhos = [p.name + ("/" if p.is_dir() else "") for p in itens if p.is_dir() or p.name not in NOMES_PERMITIDOS]
    if estranhos:
        raise SystemExit(
            "a pasta tem o que o atualizador não aceita no zip: %s.\n"
            "Só entram %s, na raiz. Tire o resto da pasta (ou exporte para uma pasta limpa) e rode de novo."
            % (", ".join(estranhos), ", ".join(NOMES_PERMITIDOS))
        )
    if NOME_DO_EXE not in [p.name for p in itens]:
        raise SystemExit("a pasta não tem %s: exporte a build antes de zipar" % NOME_DO_EXE)
    total = sum(p.stat().st_size for p in itens)
    destino.parent.mkdir(parents=True, exist_ok=True)
    livre = shutil.disk_usage(destino.parent).free
    if livre < total + 64 * 1048576:
        raise SystemExit("falta espaço para o zip em %s: há %s livres e o zip pode chegar a %s" % (destino.parent, em_gb(livre), em_gb(total)))
    parcial = destino.with_name(destino.name + ".parcial")
    t0 = time.time()
    try:
        # allowZip64=False: um arquivo grande demais para o zip comum falha aqui, em vez de sair com o extra
        # ZIP64 que o atualizador recusa.
        with zipfile.ZipFile(parcial, "w", compression=zipfile.ZIP_DEFLATED, allowZip64=False) as zf:
            for caminho in itens:
                dados = caminho.stat()
                data = time.localtime(dados.st_mtime)[:6]
                info = zipfile.ZipInfo(caminho.name, date_time=data if data[0] >= 1980 else (1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.create_system = 0
                info.external_attr = 0o100644 << 16
                info.extra = b""
                info.file_size = dados.st_size
                print("zipando %s (%s)..." % (caminho.name, em_gb(dados.st_size)), flush=True)
                with open(caminho, "rb") as origem, zf.open(info, "w") as saida:
                    copiado = 0
                    proximo = 256 * 1048576
                    while True:
                        bloco = origem.read(1 << 20)
                        if not bloco:
                            break
                        saida.write(bloco)
                        copiado += len(bloco)
                        if copiado >= proximo:
                            print("  %s de %s" % (em_gb(copiado), em_gb(dados.st_size)), flush=True)
                            proximo += 256 * 1048576
        print("zip gravado em %.0f s." % (time.time() - t0), flush=True)
        recusas = conferir_tudo(parcial, build, destino.name)
        if recusas == 0:
            parcial.replace(destino)
        else:
            print("O zip recusado não fica em %s." % destino)
        return recusas
    finally:
        if parcial.exists():
            parcial.unlink()


# --- conferir ---------------------------------------------------------------------------------------------------------


def conferir_tudo(zip_: Path, build: int = None, nome: str = None) -> int:
    """Confere o zip contra as builds anteriores que o enxergam e contra o código desta árvore. Devolve quantas recusam."""
    atual = regra_do_codigo()
    entradas = resumo_do_zip(zip_)
    exe_bytes = next((e[1] for e in entradas if e[0].split("/")[-1] == NOME_DO_EXE), 0)
    zip_bytes = zip_.stat().st_size
    print("Zip %s: %s, %d entrada(s)." % (nome or zip_.name, em_gb(zip_bytes), len(entradas)))
    for dentro, expandido, ids in entradas:
        print("  %s  %s  extras: %s" % (dentro, em_gb(expandido), ", ".join("0x%04x" % i for i in ids) or "nenhum"))
    build = build if build is not None else build_do_historico()
    enxergam, nao_enxergam = regras_das_builds_anteriores(zip_bytes, exe_bytes, build, atual)
    recusas = 0
    for regra in enxergam + [atual]:
        motivo = conferir_zip(zip_, regra)
        if motivo:
            recusas += 1
            print("%s: RECUSADO: %s" % (regra.descricao(), motivo))
        else:
            print("%s: OK" % regra.descricao())
    for regra, dados in nao_enxergam:
        print("%s: não enxerga esta build (limites de %s / %s), nada a conferir." % (regra.nome, em_gb(int(dados.get("max_zip", 0))), em_gb(int(dados.get("max_extraido", 0)))))
    if recusas:
        print("Há atualizador que recusaria este zip: empacote com este script (python tools/prototipo_3d/zipar_build.py <pasta> <zip>), sem tar.exe.")
    return recusas


def main(argv=None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Zipa a pasta da build sem extras e confere o zip contra o atualizador.")
    ap.add_argument("caminhos", nargs="+", metavar="CAMINHO", help="PASTA ZIP para zipar; com --conferir ou --veredito, o(s) zip(s)")
    ap.add_argument("--conferir", action="store_true", help="só confere o zip (contra as builds anteriores que o enxergam e o código desta árvore)")
    ap.add_argument("--veredito", action="store_true", help="uma linha, OK ou RECUSADO: motivo, por zip, contra o código desta árvore (para ferramentas e testes)")
    ap.add_argument("--extras", help="com --veredito: uma regra avulsa que aceita só estes extras, como 0x5455,0x000a (a da Build 11)")
    ap.add_argument("--build", type=int, help="o número da build que fecha (padrão: build_numero de data/historico_3d.json)")
    args = ap.parse_args(argv)
    try:
        if args.veredito:
            regra = regra_do_codigo()
            if args.extras:
                regra = Regra("avulsa", tuple(int(i, 0) for i in args.extras.split(",") if i.strip()), regra.max_zip, regra.max_extraido, regra.max_entradas)
            recusou = 0
            for caminho in args.caminhos:
                motivo = conferir_zip(caminho, regra)
                print("RECUSADO: " + motivo if motivo else "OK")
                recusou += 1 if motivo else 0
            return 1 if recusou else 0
        if args.conferir:
            recusas = sum(conferir_tudo(Path(c), args.build) for c in args.caminhos)
            return 1 if recusas else 0
        if len(args.caminhos) != 2:
            ap.error("para zipar, dê a pasta da build e o zip de saída")
        return 1 if zipar(Path(args.caminhos[0]), Path(args.caminhos[1]), args.build) else 0
    except SystemExit as erro:
        if isinstance(erro.code, str):
            print("ERRO: " + erro.code)
            return 2
        raise
    except OSError as erro:
        print("ERRO: %s" % erro)
        return 2


if __name__ == "__main__":
    sys.exit(main())
