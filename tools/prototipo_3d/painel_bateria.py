"""Painel ao vivo da bateria: lê o log do testar.ps1 e empurra o estado para a página por SSE.

    .\tools\prototipo_3d\testar.ps1 -Push *> D:\bateria.log      # a bateria escreve o log
    python tools/prototipo_3d/painel_bateria.py D:\bateria.log 8765 "Bateria"
    ->  http://127.0.0.1:8765/  (a página recebe o estado ao vivo, sem recarregar)
"""
import json, re, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

LOG = Path(sys.argv[1])
PORTA = int(sys.argv[2]) if len(sys.argv) > 2 else 8765
TITULO = sys.argv[3] if len(sys.argv) > 3 else 'Bateria'
PAGINA = Path(__file__).with_name('painel_bateria.html')

LINHA = re.compile(r'^\[\s*(\d+)/(\d+)\]\s+(ok|FALHOU|TRAVOU|NAO ABRE)\s+(\S+)\s+(\d+)s\s*(.*)$')
RODANDO = re.compile(r'\.\.\. rodando: (.*?)\s+\(faltam (\d+) na fila\)')
INICIO = time.time()


def ler():
    if not LOG.exists():
        return ''
    dados = LOG.read_bytes()
    if dados.startswith((b'\xff\xfe', b'\xfe\xff')):
        return dados.decode('utf-16', 'replace')
    try:
        return dados.decode('utf-8-sig')
    except UnicodeDecodeError:
        return dados.decode('cp1252', 'replace')


def estado():
    texto = ler()
    total, feitos, rodando, fila, fim = 0, [], [], None, ''
    m = re.search(r'portoes: (\d+) analisados, (\d+) a rodar, (\d+) reaproveitados', texto)
    if m:
        total = int(m.group(2))
    for l in texto.splitlines():
        a = LINHA.match(l)
        if a:
            feitos.append({'status': a.group(3), 'nome': a.group(4), 'seg': int(a.group(5)), 'msg': a.group(6).strip()})
            total = int(a.group(2))
            continue
        r = RODANDO.search(l)
        if r:
            rodando = []
            for x in r.group(1).split(','):
                partes = x.strip().rsplit(' ', 1)
                if partes and partes[0]:
                    rodando.append({'nome': partes[0], 'seg': partes[1] if len(partes) > 1 else ''})
            fila = int(r.group(2))
        if 'reprovado(s)' in l or 'portoes rodados passaram' in l or 'PUSH:' in l:
            fim = l.strip()
    nomes = {f['nome'] for f in feitos}
    rodando = [x for x in rodando if x['nome'] not in nomes]
    # O testar.ps1 escreve no log a cada ~15 s enquanto há teste rodando: log parado
    # há mais de 45 s sem a linha final quer dizer que a bateria foi interrompida.
    parado_ha = int(time.time() - LOG.stat().st_mtime) if texto else 0
    return {'titulo': TITULO, 'total': total, 'feitos': feitos, 'rodando': rodando, 'fila': fila,
            'fim': fim, 'tem_log': bool(texto), 'parado_ha': parado_ha if not fim and parado_ha > 45 else 0,
            'inicio_painel': LOG.stat().st_ctime if LOG.exists() else INICIO}


class Painel(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path.startswith('/eventos'):
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            ultimo = None
            try:
                while True:
                    atual = json.dumps(estado(), ensure_ascii=False)
                    if atual != ultimo:
                        self.wfile.write(f'data: {atual}\n\n'.encode('utf-8'))
                        ultimo = atual
                    else:
                        self.wfile.write(b': ping\n\n')
                    self.wfile.flush()
                    time.sleep(1)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
                return
        corpo = PAGINA.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)


ThreadingHTTPServer.daemon_threads = True
print(f'painel em http://127.0.0.1:{PORTA}/', flush=True)
ThreadingHTTPServer(('127.0.0.1', PORTA), Painel).serve_forever()
