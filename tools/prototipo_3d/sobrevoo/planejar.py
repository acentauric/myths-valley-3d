"""PLANEJA O SOBREVOO DO MENU: um laço fechado e suave que contorna árvores e casas
PELOS LADOS, sempre a ~16 m do chão, e grava em data/sobrevoo_menu.json.

    python tools/prototipo_3d/sobrevoo/planejar.py --geometria=<pasta>/geometria_uniao.json

Precisa de numpy e scipy. A geometria vem do extrator (extrair_geometria.gd, um estilo
por vez e depois --estilo=uniao): o voo tem de livrar o Tripo E o procedural.

Por que offline: o menu monta o vale inteiro antes de aparecer, e medir obstáculo de
verdade (triângulo, não AABB) custa minutos. Planejado aqui, o menu só interpola 720
amostras, e os portões tests/sobrevoo_livre*.gd conferem o trajeto gravado contra o
vale de hoje.

O que o autor pediu, e o que cada parte faz por isso:
- "nunca atravesse objetos": folga de 5 m da geometria real em todo quadro. O campo
  de folga da grade erra até 1,3 m, por isso a otimização pede FOLGA_ALVO_M = 7.
- "não suba": a altura é o relevo suavizado + 16 m, presa em [14,6; 17,4] m. Quem
  desvia é o traçado, de lado.
- "desvie de forma suave, sem movimento brusco": a curva é uma B-spline periódica
  (curvatura contínua), a energia castiga curvatura e a variação dela, e a velocidade
  respeita guinada, aceleração lateral e tangencial no nível do voo de antes (o desenho
  aprovado já virava a 21,6 graus/s nas pontas, com 1,32 m/s2 de lado).
- O desenho continua o mesmo: sai do píer, contorna a praça e volta pelo outro lado,
  em 72 s. A ida e a volta NÃO duram 36 s cada: a volta contorna mais árvores, e
  forçar a metade exata estoura a guinada.

Unidades: posições em unidades do mundo (u), folgas e limites em metros.
"""
import argparse
import datetime
import json
import os

import numpy as np
from scipy.ndimage import map_coordinates
from scipy.optimize import lsq_linear, minimize

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
DADO = os.path.join(RAIZ, 'data', 'sobrevoo_menu.json')

# ---- desenho (os mesmos números do abertura.gd e de docs/mundo/VALE_VIVO_3D.md) ----
SEGUNDOS = 72.0
AMOSTRAS = 720                 # uma a cada 0,1 s; o menu interpola Catmull-Rom periódica
ALTURA_M = 16.0
FAIXA_ALTURA_M = (14.6, 17.4)  # dentro dos 14-18 m que o avaliador cobra
OLHAR_M = 56.0                 # alvo adiante, na horizontal (perto: LOD da mata)
PIER_MAX_M = 12.0              # a curva passa a até isto do píer...
PRACA_MAX_M = 28.0             # ...e da praça (cercada de árvores: mais perto não cabe)

# ---- conforto (no nível do voo aprovado antes do contorno) ----
GUINADA_MAX = 22.5             # graus/s
ACEL_LATERAL_MAX = 1.25        # m/s2 (v2 x curvatura); a interpolação soma ~0,15
ACEL_TANGENCIAL_MAX = 0.8      # m/s2 ao frear e acelerar

# ---- forma ----
CONTROLES = 22                 # pontos de controle da B-spline periódica
DENSAS = 1600                  # amostras da curva dentro da otimização
FOLGA_ALVO_M = 7.0             # campo da grade - margem de erro do campo (1,3 m) > 5 m
PESOS = dict(curv=2000.0, dcurv=8000.0, folga=5.0, ancora=2.5, comp=0.002, tempo=20.0)
TEMPO_FOLGA_S = 3.0            # a otimização mira 69 s: o limite de aceleração come o resto


class Geometria:
    """Cabeçalho + binário do extrator: chão por célula e campo de folga por altura."""

    def __init__(self, caminho):
        self.cab = json.load(open(caminho, encoding='utf-8'))
        nx, nz = self.cab['nx'], self.cab['nz']
        n = nx * nz
        bruto = np.fromfile(os.path.join(os.path.dirname(caminho), self.cab['binario']), dtype=np.uint8)
        blocos = {b['nome']: b for b in self.cab['blocos']}
        o = blocos['chao']['offset']
        self.chao = np.frombuffer(bruto[o:o + 4 * n].tobytes(), dtype='<f4').reshape(nz, nx)
        self.alturas = blocos['campo']['alturas_m']
        o = blocos['campo']['offset']
        self.campo = np.frombuffer(bruto[o:o + 4 * n * len(self.alturas)].tobytes(), dtype='<f4').reshape(len(self.alturas), nz, nx)
        self.escala = self.cab['metros_por_unidade']
        self.celula = self.cab['celula_u']
        self.ox, self.oz = self.cab['origem_u']
        self.pier = np.array([self.cab['pier'][0], self.cab['pier'][2]])
        self.praca = np.array([self.cab['praca'][0], self.cab['praca'][2]])

    def _indices(self, x, z):
        # O chão e o campo valem no CENTRO da célula.
        return (np.asarray(z) - self.oz) / self.celula - 0.5, (np.asarray(x) - self.ox) / self.celula - 0.5

    def chao_em(self, x, z):
        iz, ix = self._indices(x, z)
        return map_coordinates(self.chao, [iz, ix], order=1, mode='nearest')

    def folga_em(self, x, z, altura_m=ALTURA_M):
        iz, ix = self._indices(x, z)
        camada = np.interp(altura_m, self.alturas, np.arange(len(self.alturas)))
        return map_coordinates(self.campo, [np.full(np.shape(iz), camada), iz, ix], order=1, mode='nearest')


def base_bspline(controles, amostras):
    """Matrizes da B-spline cúbica uniforme periódica e das duas primeiras derivadas."""
    u = np.arange(amostras) / amostras * controles
    i = np.floor(u).astype(int)
    t = u - i
    B, D1, D2 = (np.zeros((amostras, controles)) for _ in range(3))
    b = [(1 - t) ** 3 / 6, (3 * t ** 3 - 6 * t ** 2 + 4) / 6, (-3 * t ** 3 + 3 * t ** 2 + 3 * t + 1) / 6, t ** 3 / 6]
    d1 = [-(1 - t) ** 2 / 2, (9 * t ** 2 - 12 * t) / 6, (-9 * t ** 2 + 6 * t + 3) / 6, t ** 2 / 2]
    d2 = [(1 - t), (18 * t - 12) / 6, (-18 * t + 6) / 6, t]
    linhas = np.arange(amostras)
    for k in range(4):
        colunas = (i - 1 + k) % controles
        B[linhas, colunas] += b[k]
        D1[linhas, colunas] += d1[k] * controles
        D2[linhas, colunas] += d2[k] * controles * controles
    return B, D1, D2


def suavizar_periodico(x, janela):
    if janela < 1:
        return x
    nucleo = np.ones(2 * janela + 1) / (2 * janela + 1)
    return np.convolve(np.concatenate([x[-janela:], x, x[:janela]]), nucleo, mode='valid')


def limitar_aceleracao(v, ds, acel):
    """v2 <= v_j2 + 2a.distância, para a frente e para trás, numa passada vetorizada:
    mínimo acumulado sobre duas voltas, porque o laço é fechado."""
    n = len(v)
    s = np.concatenate([[0], np.cumsum(ds)])
    s2 = np.concatenate([s[:-1], s[:-1] + s[-1]])
    a2 = 2 * acel
    v2 = np.concatenate([v, v]) ** 2
    v2 = np.minimum(v2, a2 * s2 + np.minimum.accumulate(v2 - a2 * s2))
    v2 = np.minimum(v2, -a2 * s2 + np.minimum.accumulate((v2 + a2 * s2)[::-1])[::-1])
    return np.sqrt(np.minimum(v2[:n], v2[n:]))


def velocidade_limite(curvatura_m):
    k = np.maximum(np.abs(curvatura_m), 1e-6)
    return np.minimum(np.radians(GUINADA_MAX) / k, np.sqrt(ACEL_LATERAL_MAX / k))


class Planejador:
    def __init__(self, geo):
        self.geo = geo
        self.B, self.D1, self.D2 = base_bspline(CONTROLES, DENSAS)

    def tempo_minimo(self, C, curvatura_m, ds_m):
        v = limitar_aceleracao(np.minimum(velocidade_limite(suavizar_periodico(np.abs(curvatura_m), 4)), 40.0), ds_m, ACEL_TANGENCIAL_MAX)
        return float(np.sum(ds_m / v))

    def energia(self, vetor, detalhar=False):
        g = self.geo
        P = vetor.reshape(CONTROLES, 2)
        C, C1, C2 = self.B @ P, self.D1 @ P, self.D2 @ P
        rapidez = np.linalg.norm(C1, axis=1) + 1e-9
        ds_m = rapidez / DENSAS * g.escala
        curvatura_m = (C1[:, 0] * C2[:, 1] - C1[:, 1] * C2[:, 0]) / rapidez ** 3 / g.escala
        falta = np.maximum(0.0, FOLGA_ALVO_M - g.folga_em(C[:, 0], C[:, 1]))
        variacao = np.diff(np.concatenate([curvatura_m, curvatura_m[:1]])) / (ds_m + 1e-9)
        pier = np.min(np.linalg.norm(C - g.pier, axis=1)) * g.escala
        praca = np.min(np.linalg.norm(C - g.praca, axis=1)) * g.escala
        tempo = self.tempo_minimo(C, curvatura_m, ds_m)
        partes = dict(
            curv=PESOS['curv'] * np.sum(curvatura_m ** 2 * ds_m),
            dcurv=PESOS['dcurv'] * np.sum(variacao ** 2 * ds_m),
            folga=PESOS['folga'] * np.sum(falta ** 2 * ds_m),
            ancora=PESOS['ancora'] * (max(0.0, pier - PIER_MAX_M) ** 2 + max(0.0, praca - PRACA_MAX_M) ** 2),
            comp=PESOS['comp'] * np.sum(ds_m),
            tempo=PESOS['tempo'] * max(0.0, tempo - (SEGUNDOS - TEMPO_FOLGA_S)) ** 2,
        )
        total = float(sum(partes.values()))
        if detalhar:
            return dict(total=total, tempo_minimo_s=tempo, pier_m=pier, praca_m=praca,
                        folga_campo_min_m=float(g.folga_em(C[:, 0], C[:, 1]).min()),
                        raio_min_m=float(1.0 / np.abs(curvatura_m).max()), **{k: float(v) for k, v in partes.items()})
        return total

    def otimizar(self, P, rodadas=3):
        for _ in range(rodadas):
            r = minimize(self.energia, P.ravel(), method='L-BFGS-B', options=dict(maxiter=400, maxfun=16000))
            P = r.x.reshape(CONTROLES, 2)
        return P

    def ajustar(self, pontos):
        """Pontos de controle que melhor reproduzem uma curva fechada amostrada."""
        pontos = np.asarray(pontos, float)
        alvo = pontos[np.linspace(0, len(pontos), DENSAS, endpoint=False).astype(int)]
        return np.linalg.lstsq(self.B, alvo, rcond=None)[0]

    def trajeto(self, P):
        """Tempo, altura e alvo: um só perfil de velocidade periódico (sem emenda)."""
        g = self.geo
        B, D1, _ = base_bspline(CONTROLES, 2400)
        C = B @ P
        C = np.roll(C, -int(np.argmin(np.linalg.norm(C - g.pier, axis=1))), axis=0)  # t = 0 no píer
        Cp, Cm = np.roll(C, -1, 0), np.roll(C, 1, 0)
        a, b, c = (np.linalg.norm(x, axis=1) for x in (C - Cm, Cp - C, Cp - Cm))
        area2 = np.abs((C[:, 0] - Cm[:, 0]) * (Cp[:, 1] - Cm[:, 1]) - (C[:, 1] - Cm[:, 1]) * (Cp[:, 0] - Cm[:, 0]))
        curvatura_m = suavizar_periodico(2 * area2 / (a * b * c + 1e-12) / g.escala, 12)
        ds_m = b * g.escala
        teto = velocidade_limite(curvatura_m)
        baixo, alto = 0.5, 60.0
        for _ in range(50):
            meio = (baixo + alto) / 2
            v = limitar_aceleracao(limitar_aceleracao(np.minimum(teto, meio), ds_m, ACEL_TANGENCIAL_MAX), ds_m, ACEL_TANGENCIAL_MAX)
            if np.sum(ds_m / v) > SEGUNDOS:
                baixo = meio
            else:
                alto = meio
        v = limitar_aceleracao(limitar_aceleracao(np.minimum(teto, alto), ds_m, ACEL_TANGENCIAL_MAX), ds_m, ACEL_TANGENCIAL_MAX)
        t = np.concatenate([[0], np.cumsum(ds_m / v)])
        if abs(t[-1] - SEGUNDOS) > 0.05:
            raise SystemExit('NAO CABE: o laço pede %.1f s com estes limites de conforto' % t[-1])
        tau = np.arange(AMOSTRAS) * SEGUNDOS / AMOSTRAS
        x = np.interp(tau, t, np.concatenate([C[:, 0], C[:1, 0]]))
        z = np.interp(tau, t, np.concatenate([C[:, 1], C[:1, 1]]))
        chao = g.chao_em(x, z)
        y = alisar_na_faixa(chao + ALTURA_M / g.escala, chao + FAIXA_ALTURA_M[0] / g.escala, chao + FAIXA_ALTURA_M[1] / g.escala)
        olho = np.stack([x, y, z], 1)
        # Alvo: tangente suavizada (±0,6 s) a OLHAR_M, com inclinação leve e sem pulos
        # quando o chão sob o alvo muda.
        d = np.roll(olho, -1, 0) - np.roll(olho, 1, 0)
        dx, dz = suavizar_periodico(d[:, 0], 6), suavizar_periodico(d[:, 2], 6)
        norma = np.sqrt(dx ** 2 + dz ** 2) + 1e-9
        ax, az = x + dx / norma * OLHAR_M / g.escala, z + dz / norma * OLHAR_M / g.escala
        chao_alvo = g.chao_em(ax, az)
        ay = np.maximum(y - 5.0 / g.escala, chao_alvo + 4.0 / g.escala)
        ay = alisar_na_faixa(ay, np.minimum(chao_alvo + 2.5 / g.escala, y + 1.0 / g.escala), y + 2.0 / g.escala)
        return olho, np.stack([ax, ay, az], 1), dict(t_praca_s=float(t[int(np.argmin(np.linalg.norm(C - g.praca, axis=1)))]),
                                                     velocidade_m_s=[float(v.min()), float(v.max())])


def alisar_na_faixa(y, baixo, alto, peso_referencia=1e-9):
    """Mínimos quadrados com caixa: a terceira diferença (o solavanco vertical) o menor
    possível, sem sair de [baixo, alto]. Alisar e depois cortar deixaria quinas."""
    n = len(y)
    I = np.eye(n)
    D3 = np.roll(I, 2, 1) - 3 * np.roll(I, 1, 1) + 3 * I - np.roll(I, -1, 1)
    A = np.vstack([D3, np.sqrt(peso_referencia) * I])
    b = np.concatenate([np.zeros(n), np.sqrt(peso_referencia) * y])
    return lsq_linear(A, b, bounds=(baixo, alto), method='bvls', max_iter=5000).x


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--geometria', required=True, help='geometria_uniao.json do extrator')
    parser.add_argument('--inicial', default=DADO, help='trajeto com "controles_u" para começar (padrão: o gravado)')
    parser.add_argument('--saida', default=DADO)
    parser.add_argument('--rodadas', type=int, default=3, help='0 = só regrava o trajeto a partir dos controles')
    args = parser.parse_args()
    geo = Geometria(args.geometria)
    plano = Planejador(geo)
    inicial = json.load(open(args.inicial, encoding='utf-8'))
    if 'controles_u' in inicial:
        P = np.array(inicial['controles_u'], float)
    else:
        # Sem controles, parte de qualquer laço fechado amostrado ("olho" ou lista de [x, z]).
        pontos = inicial['olho'] if isinstance(inicial, dict) else inicial
        P = plano.ajustar([[p[0], p[-1]] for p in pontos])
    print('inicial', plano.energia(P.ravel(), True))
    if args.rodadas > 0:
        P = plano.otimizar(P, args.rodadas)
    resumo = plano.energia(P.ravel(), True)
    print('final  ', resumo)
    olho, alvo, extra = plano.trajeto(P)
    cab = geo.cab
    dado = {
        'versao': 1,
        'descricao': 'Sobrevoo do menu planejado por tools/prototipo_3d/sobrevoo/planejar.py: '
                     'contorna pelos lados a ~16 m, conferido por tests/sobrevoo_livre*.gd.',
        'gerado_em': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'amostras': AMOSTRAS, 'segundos': SEGUNDOS, 'metros_por_unidade': geo.escala,
        'pier': cab['pier'], 'praca': cab['praca'],
        'ancoras_por_estilo': cab.get('ancoras_por_estilo', {}),
        'limites': {'guinada_graus_s': GUINADA_MAX, 'acel_lateral_m_s2': ACEL_LATERAL_MAX,
                    'acel_tangencial_m_s2': ACEL_TANGENCIAL_MAX, 'altura_m': list(FAIXA_ALTURA_M),
                    'folga_alvo_campo_m': FOLGA_ALVO_M},
        'planejamento': {**{k: round(v, 3) for k, v in resumo.items()}, **extra},
        'controles_u': np.round(P, 5).tolist(),
        # 5 casas (0,04 mm): com 4, o arredondamento vira ruído quando se deriva duas
        # vezes a cada 0,1 s (a aceleração lateral medida subia 0,06 m/s2).
        'olho': np.round(olho, 5).tolist(),
        'alvo': np.round(alvo, 5).tolist(),
    }
    with open(args.saida, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(dado, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print('gravado', args.saida)


if __name__ == '__main__':
    main()
