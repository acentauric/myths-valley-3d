"""Copia os GLBs exportados pelo lote do Tripo Studio (Downloads) para o projeto.

Para cada chave do catálogo (`catalogo_assets.gd`), procura `<chave>_tripo.glb` (ou a
cópia mais recente `<chave>_tripo (n).glb`) em Downloads, guarda o original em
`.assets-raw/tripo/<pasta>/` e copia para `assets/prototipo_3d/<caminho do
catálogo>`. Não sobrescreve um GLB do projeto mais novo que o download.

Uso: python sincronizar_downloads.py [pasta_downloads] [--chaves a,b] [--exceto c,d]
  --chaves  só estas chaves do catálogo (o lote da vez);
  --exceto  pula estas (um GLB que ainda vai ser medido por alguém antes de trocar).
"""
import os, re, shutil, sys, glob, hashlib

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATALOGO = os.path.join(RAIZ, "scripts", "prototipo_3d", "catalogo_assets.gd")
ASSETS = os.path.join(RAIZ, "assets", "prototipo_3d")
RAW = os.path.join(RAIZ, ".assets-raw", "tripo")


def catalogo():
    texto = open(CATALOGO, encoding="utf-8").read()
    return dict(re.findall(r'"([a-z_]+)":\s*\{"tripo":\s*"([^"]+)"', texto))


LIMITE_BYTES = 25_000_000  # acima disso é o HD cru, não a exportação da Malha Smart


def candidato(downloads, base):
    padrao = os.path.join(downloads, f"{base}*.glb")
    arquivos = [a for a in glob.glob(padrao)
                if re.fullmatch(rf"{re.escape(base)}( \(\d+\))?\.glb", os.path.basename(a))
                and os.path.getsize(a) <= LIMITE_BYTES]
    if not arquivos:
        return None
    return max(arquivos, key=os.path.getmtime)


def sha(caminho):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def _lista(opcao, args):
    if opcao in args:
        i = args.index(opcao)
        valor = args[i + 1] if i + 1 < len(args) else ""
        del args[i:i + 2]
        return {c.strip() for c in valor.split(",") if c.strip()}
    return None


def main():
    args = sys.argv[1:]
    so, exceto = _lista("--chaves", args), _lista("--exceto", args) or set()
    downloads = args[0] if args else os.path.join(os.path.expanduser("~"), "Downloads")
    copiados, faltando = [], []
    for chave, caminho in catalogo().items():
        if (so is not None and chave not in so) or chave in exceto:
            continue
        origem = candidato(downloads, os.path.splitext(os.path.basename(caminho))[0])
        if origem is None:
            faltando.append(chave)
            continue
        destino = os.path.join(ASSETS, caminho)
        bruto = os.path.join(RAW, os.path.dirname(caminho), os.path.basename(caminho))
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        os.makedirs(os.path.dirname(bruto), exist_ok=True)
        # O GLB do projeto mais novo que o download fica: um download antigo esquecido em
        # Downloads (de outro lote) não pode desfazer a versão que está no Git.
        if os.path.exists(destino) and os.path.getmtime(destino) >= os.path.getmtime(origem):
            continue
        shutil.copy2(origem, bruto)
        shutil.copy2(origem, destino)
        copiados.append((chave, os.path.getsize(origem)))
    for chave, tamanho in copiados:
        print(f"copiado {chave:22s} {tamanho/1e6:6.2f} MB")
    print(f"{len(copiados)} copiados; faltando ({len(faltando)}): {', '.join(faltando)}")


if __name__ == "__main__":
    main()
