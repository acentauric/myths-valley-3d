"""Baixa os GLBs exportados pelo lote do Tripo Studio a partir das URLs assinadas.

Complemento de lote_producao.js para quando o Chrome segura o download (aba escondida ou
janela minimizada): `__mv.links()` devolve {chave: url}; salve esse JSON com o `filename` do
browser_evaluate e rode este script. Cada GLB vai para Downloads/<chave>_tripo.glb, como o
download do navegador, e segue o fluxo normal (sincronizar_downloads.py). Não baixa de novo
o que já está em Downloads com o mesmo tamanho.

Uso: python baixar_links.py links.json [pasta_downloads]
"""
import json, os, sys, urllib.request


def main():
    links = json.load(open(sys.argv[1], encoding="utf-8"))
    if isinstance(links, str):  # o browser_evaluate às vezes salva o resultado como texto JSON
        links = json.loads(links)
    downloads = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.expanduser("~"), "Downloads")
    baixados, iguais, falhas = [], 0, []
    for chave, url in sorted(links.items()):
        destino = os.path.join(downloads, f"{chave}_tripo.glb")
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                tamanho = int(r.headers.get("Content-Length") or 0)
                if tamanho and os.path.exists(destino) and os.path.getsize(destino) == tamanho:
                    iguais += 1
                    continue
                dados = r.read()
            with open(destino + ".parcial", "wb") as f:
                f.write(dados)
            os.replace(destino + ".parcial", destino)
            baixados.append((chave, len(dados)))
        except Exception as e:  # uma URL vencida não derruba o resto do lote
            falhas.append(f"{chave}: {e}")
    for chave, tamanho in baixados:
        print(f"baixado {chave:22s} {tamanho/1e6:6.2f} MB")
    print(f"{len(baixados)} baixados, {iguais} já estavam em Downloads, {len(falhas)} falhas")
    for f in falhas:
        print("  falhou", f)


if __name__ == "__main__":
    main()
