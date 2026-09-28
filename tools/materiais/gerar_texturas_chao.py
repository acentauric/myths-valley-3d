"""Gera texturas de chão para o protótipo 3D: terra batida, chão de praça, areia de praia
(tileáveis) e a base das árvores (decalque único, com transparência).

As imagens são procedurais e determinísticas (semente fixa), pensadas para 1887 no
Recôncavo: estrada de terra batida com sulcos de carro de boi e chão de praça de
terra com seixos. Rodar a partir da raiz do repositório:

    python prototipo_3d/tools/materiais/gerar_texturas_chao.py

Saída: prototipo_3d/assets/prototipo_3d/materiais/*.png (1024×1024, sem emenda).
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / "assets/prototipo_3d/materiais"
SIZE = 1024
SEED = 1887


def _value_noise(rng: np.random.Generator, size: int, cells: int) -> np.ndarray:
    """Ruído de valor periódico (tileável) interpolado com smoothstep."""
    grid = rng.random((cells, cells))
    grid = np.concatenate([grid, grid[:1]], axis=0)
    grid = np.concatenate([grid, grid[:, :1]], axis=1)
    coords = np.linspace(0.0, cells, size, endpoint=False)
    x0 = np.floor(coords).astype(int)
    fx = coords - x0
    fx = fx * fx * (3.0 - 2.0 * fx)
    a = grid[x0[:, None], x0[None, :]]
    b = grid[x0[:, None], (x0 + 1)[None, :]]
    c = grid[(x0 + 1)[:, None], x0[None, :]]
    d = grid[(x0 + 1)[:, None], (x0 + 1)[None, :]]
    top = a + (b - a) * fx[None, :]
    bottom = c + (d - c) * fx[None, :]
    return top + (bottom - top) * fx[:, None]


def _fbm(rng: np.random.Generator, size: int, base_cells: int, octaves: int, gain: float = 0.5) -> np.ndarray:
    total = np.zeros((size, size))
    amplitude = 1.0
    cells = base_cells
    for _ in range(octaves):
        total += _value_noise(rng, size, cells) * amplitude
        amplitude *= gain
        cells *= 2
    total -= total.min()
    return total / max(total.max(), 1e-6)


def _mix(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    return a * (1.0 - t[..., None]) + b * t[..., None]


def _pebbles(rng: np.random.Generator, size: int, count: int, radius_range: tuple[float, float]) -> np.ndarray:
    """Máscara suave de seixos, carimbada localmente com índices em módulo (mantém a emenda)."""
    mask = np.zeros((size, size))
    for _ in range(count):
        cx, cy = rng.random(2) * size
        r = rng.uniform(*radius_range)
        span = int(np.ceil(r)) + 1
        ys = (np.arange(int(cy) - span, int(cy) + span + 1)) % size
        xs = (np.arange(int(cx) - span, int(cx) + span + 1)) % size
        dy = (np.arange(int(cy) - span, int(cy) + span + 1) - cy)[:, None] * 1.3
        dx = (np.arange(int(cx) - span, int(cx) + span + 1) - cx)[None, :]
        stamp = np.clip(1.0 - np.sqrt(dx * dx + dy * dy) / r, 0.0, 1.0) ** 0.6
        sub = mask[np.ix_(ys, xs)]
        mask[np.ix_(ys, xs)] = np.maximum(sub, stamp)
    return mask


def terra_batida() -> Image.Image:
    rng = np.random.default_rng(SEED)
    base = _fbm(rng, SIZE, 4, 5)
    fine = _fbm(rng, SIZE, 32, 3, 0.6)
    ochre = np.array([0.72, 0.60, 0.42])
    dark = np.array([0.52, 0.41, 0.28])
    pale = np.array([0.82, 0.72, 0.53])
    color = _mix(dark, ochre, base)
    color = _mix(color, pale, np.clip(fine * 0.55, 0.0, 1.0))
    # Sulcos de roda de carro de boi ao longo do eixo V (a rua corre no eixo vertical da textura).
    u = np.linspace(0.0, 1.0, SIZE, endpoint=False)[None, :]
    wobble = (_fbm(rng, SIZE, 2, 2) - 0.5) * 0.03
    ruts = np.zeros((SIZE, SIZE))
    for center in (0.30, 0.70):
        ruts += np.exp(-((u + wobble - center) ** 2) / (2 * 0.028**2))
    ruts = np.clip(ruts, 0.0, 1.0)
    color = _mix(color, dark * 0.92, ruts * 0.55)
    # Faixa central mais clara e pisoteada.
    crown = np.exp(-((u - 0.5) ** 2) / (2 * 0.09**2)) * np.ones((SIZE, 1))
    color = _mix(color, pale, crown * 0.22)
    pebbles = _pebbles(rng, SIZE, 260, (2.5, 6.5))
    pebble_color = np.array([0.66, 0.62, 0.55])
    color = _mix(color, pebble_color, pebbles * 0.8)
    grain = (rng.random((SIZE, SIZE)) - 0.5) * 0.05
    color = np.clip(color + grain[..., None], 0.0, 1.0)
    return Image.fromarray((color * 255).astype(np.uint8), "RGB")


def chao_praca() -> Image.Image:
    rng = np.random.default_rng(SEED + 1)
    base = _fbm(rng, SIZE, 6, 5)
    fine = _fbm(rng, SIZE, 48, 2, 0.6)
    sand = np.array([0.84, 0.76, 0.58])
    earth = np.array([0.70, 0.60, 0.44])
    dust = np.array([0.90, 0.84, 0.68])
    color = _mix(earth, sand, base)
    color = _mix(color, dust, np.clip(fine * 0.5, 0.0, 1.0))
    # Manchas de grama rala pisoteada.
    tufts = _fbm(rng, SIZE, 10, 3)
    grass = np.array([0.56, 0.66, 0.40])
    color = _mix(color, grass, np.clip((tufts - 0.62) * 2.2, 0.0, 1.0) * 0.5)
    pebbles = _pebbles(rng, SIZE, 420, (2.0, 5.0))
    color = _mix(color, np.array([0.70, 0.67, 0.60]), pebbles * 0.75)
    grain = (rng.random((SIZE, SIZE)) - 0.5) * 0.04
    color = np.clip(color + grain[..., None], 0.0, 1.0)
    return Image.fromarray((color * 255).astype(np.uint8), "RGB")


def areia_praia() -> Image.Image:
    """Areia clara de praia da baía: tom variando em manchas, ondinhas de vento
    (periódicas, então a textura continua sem emenda), grãos escuros e conchinhas."""
    rng = np.random.default_rng(SEED + 2)
    base = _fbm(rng, SIZE, 5, 5)
    fine = _fbm(rng, SIZE, 64, 2, 0.6)
    clara = np.array([0.93, 0.88, 0.76])
    escura = np.array([0.82, 0.74, 0.58])
    color = _mix(escura, clara, base * 0.8 + 0.2)
    # Ondinhas de vento: senoide diagonal com número inteiro de ciclos (sem emenda),
    # torcida por um ruído lento.
    y, x = np.mgrid[0:SIZE, 0:SIZE] / SIZE
    torcao = _fbm(rng, SIZE, 4, 3)
    ondas = np.sin(2 * np.pi * (14 * x + 9 * y) + torcao * 9.0)
    color *= (1.0 - 0.022 * np.clip(ondas, 0.0, 1.0) * (0.4 + base))[..., None]
    color = _mix(color, clara * 1.02, np.clip(fine - 0.55, 0.0, 1.0) * 0.8)
    # Grãos escuros (mineral) e conchinhas claras.
    graos = rng.random((SIZE, SIZE)) > 0.985
    color[graos] *= 0.72
    conchas = _pebbles(rng, SIZE, 260, (1.2, 2.6))
    color = _mix(color, np.array([0.97, 0.95, 0.9]), conchas * 0.8)
    grain = (rng.random((SIZE, SIZE)) - 0.5) * 0.05
    color = np.clip(color + grain[..., None], 0.0, 1.0)
    return Image.fromarray((color * 255).astype(np.uint8), "RGB")


def base_arvore(size: int = 512, paleta: dict | None = None, semente: int = 3) -> Image.Image:
    """Decalque do pé das árvores: chão revolvido, folhas caídas e raízes saindo do
    centro, sumindo nas bordas (alfa radial com borda irregular). A paleta muda com o
    chão: terra e folhas na grama, areia revolvida na praia."""
    cores = paleta or {
        "chao": (0.30, 0.23, 0.15), "detalhe": (0.52, 0.40, 0.22),
        "claro": (0.62, 0.50, 0.28), "escuro": (0.20, 0.16, 0.10),
        "raiz": (0.40, 0.28, 0.17),
    }
    rng = np.random.default_rng(SEED + semente)
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size * 2.0 - 1.0
    raio = np.sqrt(x * x + y * y)
    angulo = np.arctan2(y, x)
    ruido = _fbm(rng, size, 8, 4)
    terra = np.array(cores["chao"])
    folha = np.array(cores["detalhe"])
    color = _mix(terra, folha, np.clip((ruido - 0.45) * 2.0, 0.0, 1.0))
    # Folhas caídas: pintas mais claras e mais escuras.
    folhas = _fbm(rng, size, 40, 2)
    color = _mix(color, np.array(cores["claro"]), np.clip((folhas - 0.62) * 4.0, 0.0, 1.0) * 0.7)
    color = _mix(color, np.array(cores["escuro"]), np.clip((0.38 - folhas) * 4.0, 0.0, 1.0) * 0.6)
    # Raízes: sete sulcos radiais, grossos no centro e afinando.
    raizes = np.zeros((size, size))
    for i in range(7):
        direcao = rng.uniform(0, 2 * np.pi)
        largura = rng.uniform(0.10, 0.16)
        alcance = rng.uniform(0.55, 0.85)
        diferenca = np.angle(np.exp(1j * (angulo - direcao - 0.25 * np.sin(raio * 9.0 + i))))
        sulco = np.clip(1.0 - np.abs(diferenca) / (largura * (1.1 - raio)), 0.0, 1.0)
        raizes = np.maximum(raizes, sulco * np.clip(1.0 - raio / alcance, 0.0, 1.0))
    color = _mix(color, np.array(cores["raiz"]), np.clip(raizes * 1.6, 0.0, 1.0))
    alfa = np.clip((1.0 - raio) * 2.2 - (ruido - 0.5) * 0.9, 0.0, 1.0)
    alfa = np.maximum(alfa, np.clip(raizes * 1.4, 0.0, 1.0) * (raio < 0.9))
    rgba = np.dstack([np.clip(color, 0, 1), alfa])
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    terra_batida().save(OUTPUT / "terra_batida_v1.png", optimize=True)
    chao_praca().save(OUTPUT / "chao_praca_v1.png", optimize=True)
    areia_praia().save(OUTPUT / "areia_praia_v1.png", optimize=True)
    base_arvore().save(OUTPUT / "base_arvore_v1.png", optimize=True)
    base_arvore(paleta={
        "chao": (0.74, 0.66, 0.50), "detalhe": (0.82, 0.75, 0.58),
        "claro": (0.88, 0.82, 0.66), "escuro": (0.60, 0.52, 0.38),
        "raiz": (0.66, 0.55, 0.38),
    }, semente=4).save(OUTPUT / "base_arvore_areia_v1.png", optimize=True)
    print("Texturas gravadas em", OUTPUT)


if __name__ == "__main__":
    main()
