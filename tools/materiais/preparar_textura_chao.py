"""Prepara as texturas de chão geradas no OpenAI para o shader do terreno.

Cada bruto de .assets-raw/openai/texturas_chao/<id>.png (tools/openai/gerar-texturas-chao.ps1)
sai em assets/prototipo_3d/materiais/<id>_v1.png, pronto para ladrilhar
(docs/mundo/SOLO_E_FRANJAS.md):

1. recorta a borda (a imagem às vezes escurece nos cantos) e reduz para 1024 px;
2. achata a baixa frequência: divide a luminância por um desfoque largo, para a
   mancha grande de um canto não virar um xadrez quando o chão repete;
3. torna a textura contínua: rola meia imagem e esconde a costura em cruz com uma
   máscara ruidosa, misturando com a imagem original no lugar;
4. grava a altura no alfa: a luminância passa-alta, normalizada. O shader mistura as
   camadas por ela (o tufo de grama sobe por cima da terra, a pedra por cima da lama);
5. grava a prévia 3x3 em <saida-previas>/<id>_3x3.jpg, para OLHAR antes de usar.

    python tools/materiais/preparar_textura_chao.py [--somente grama_baixa,lama_mangue]
        [--bruto-sufixo _semi_realista] [--previas <pasta>] [--so-previa]

Mede também a cor média (sRGB) de cada textura pronta: é por ela que o shader acerta
a tinta de cada camada com a paleta da AMBIENTACAO §7.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[2]
BRUTOS = PROJECT / ".assets-raw/openai/texturas_chao"
SAIDA = PROJECT / "assets/prototipo_3d/materiais"
LADO = 1024
RECORTE = 0.03
SEMENTE = 1887
## Raio (sigma, px) do achatamento da baixa frequência. O barro veio com manchas
## escuras de um terço da imagem, que na prévia 3x3 viravam diagonais repetidas:
## achata mais curto.
ACHATAR = {"barro_vermelho": 40.0}


def _ruido_suave(rng: np.random.Generator, lado: int, celulas: int) -> np.ndarray:
    """Ruído de valor periódico, interpolado com smoothstep, de 0 a 1."""
    grade = rng.random((celulas + 1, celulas + 1))
    grade[-1, :] = grade[0, :]
    grade[:, -1] = grade[:, 0]
    coords = np.linspace(0.0, celulas, lado, endpoint=False)
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3.0 - 2.0 * f)
    a = grade[i0[:, None], i0[None, :]]
    b = grade[i0[:, None], (i0 + 1)[None, :]]
    c = grade[(i0 + 1)[:, None], i0[None, :]]
    d = grade[(i0 + 1)[:, None], (i0 + 1)[None, :]]
    cima = a + (b - a) * f[None, :]
    baixo = c + (d - c) * f[None, :]
    return cima + (baixo - cima) * f[:, None]


def _desfoque(rgb: np.ndarray, sigma: float) -> np.ndarray:
    """Desfoque gaussiano pela FFT: a convolução é circular, então dá a volta nas
    bordas, como a textura vai ladrilhar."""
    n, m = rgb.shape[:2]
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(m)[None, :]
    nucleo = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    canais = [np.real(np.fft.ifft2(np.fft.fft2(rgb[..., k]) * nucleo)) for k in range(rgb.shape[2])]
    return np.stack(canais, axis=-1)


def _luminancia(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def preparar(bruto: Path, sigma: float = 128.0) -> np.ndarray:
    """Devolve RGBA float (0..1), contínua, com a altura no alfa."""
    imagem = Image.open(bruto).convert("RGB")
    w, h = imagem.size
    corte = int(min(w, h) * RECORTE)
    imagem = imagem.crop((corte, corte, w - corte, h - corte)).resize((LADO, LADO), Image.LANCZOS)
    rgb = np.asarray(imagem, dtype=np.float64) / 255.0
    # 2. Achatar a baixa frequência: a luminância dividida pela sua versão larga
    # (sigma 128 px, ou o de ACHATAR) e devolvida à média da imagem. A cor local continua.
    lum = _luminancia(rgb)
    larga = _desfoque(lum[..., None], sigma)[..., 0]
    media = lum.mean()
    ganho = np.clip(media / np.maximum(larga, 1e-3), 0.6, 1.6)
    rgb = np.clip(rgb * ganho[..., None], 0.0, 1.0)
    # O matiz também deriva em mancha grande: puxa metade dele para a média.
    cor_larga = _desfoque(rgb, sigma)
    rgb = np.clip(rgb - (cor_larga - rgb.reshape(-1, 3).mean(axis=0)) * 0.5, 0.0, 1.0)
    # 3. Contínua: rolar meia volta leva as bordas (que não casam) para uma cruz no
    # meio, e a borda nova vira o meio da original, que casa. A cruz é coberta por
    # retalhos de outras rolagens: perto da linha vertical, a imagem rolada só na
    # vertical (contínua através dessa linha); perto da horizontal, a rolada só na
    # horizontal; no cruzamento, a original. Cada troca segue uma borda ruidosa e
    # curta, como um retalho de chão, e não um fantasma de duas imagens somadas.
    meio = LADO // 2
    rolada = np.roll(rgb, (meio, meio), axis=(0, 1))
    so_vertical = np.roll(rgb, meio, axis=0)
    so_horizontal = np.roll(rgb, meio, axis=1)
    rng = np.random.default_rng(SEMENTE)
    eixo = np.abs(np.arange(LADO) - LADO / 2.0)
    dy = eixo[:, None] * np.ones((1, LADO))
    dx = eixo[None, :] * np.ones((LADO, 1))
    ruido = _ruido_suave(rng, LADO, 12) * 0.6 + _ruido_suave(rng, LADO, 40) * 0.4 - 0.5

    def retalho(distancia: np.ndarray, borda: float) -> np.ndarray:
        t = np.clip((borda + 10.0 - (distancia + ruido * borda * 0.8)) / 20.0, 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)

    resultado = rolada
    resultado = resultado + (so_vertical - resultado) * retalho(dx, 72.0)[..., None]
    resultado = resultado + (so_horizontal - resultado) * retalho(dy, 72.0)[..., None]
    resultado = resultado + (rgb - resultado) * retalho(np.maximum(dx, dy), 150.0)[..., None]
    # 4. Altura no alfa: a luminância menos a sua versão borrada (sigma 6 px),
    # normalizada pelos percentis para ocupar a faixa toda.
    lum = _luminancia(resultado)
    alta = lum - _desfoque(lum[..., None], 6.0)[..., 0]
    baixo, alto = np.percentile(alta, [2, 98])
    altura = np.clip((alta - baixo) / max(alto - baixo, 1e-4), 0.0, 1.0)
    # Um pouco da luminância absoluta: o claro (folha, tufo, pedra) é alto.
    altura = np.clip(altura * 0.75 + (lum - lum.min()) / max(np.ptp(lum), 1e-4) * 0.25, 0.0, 1.0)
    return np.concatenate([resultado, altura[..., None]], axis=-1)


def gravar(rgba: np.ndarray, destino: Path) -> None:
    Image.fromarray((np.clip(rgba, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), mode="RGBA").save(destino, optimize=True)


def previa(rgba: np.ndarray, destino: Path) -> None:
    rgb = (np.clip(rgba[..., :3], 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
    lado = rgb.shape[0] // 2
    pequena = np.asarray(Image.fromarray(rgb).resize((lado, lado), Image.LANCZOS))
    Image.fromarray(np.tile(pequena, (3, 3, 1))).save(destino, quality=90)


def terreiro_varrido(terra: np.ndarray, destino: Path) -> None:
    """O terreiro de cada casa (scenes/prototipo_3d/terreiro_casa.tscn): a terra batida
    varrida com uma borda oval irregular que se desfaz em grãos, em vez do retângulo
    com sulco de carro de boi. O alfa é a máscara; a cor, a terra um pouco mais clara
    no meio (onde se varre todo dia)."""
    rng = np.random.default_rng(SEMENTE + 7)
    eixo = (np.arange(LADO) + 0.5) / LADO * 2.0 - 1.0
    y, x = np.meshgrid(eixo, eixo, indexing="ij")
    raio = np.sqrt(x * x + y * y)
    angulo = np.arctan2(y, x)
    # Borda em volta: três ondas de baixa ordem (o oval torto do terreiro de verdade)
    # mais o ruído médio, e o grão fino esfarelando o último trecho.
    torto = 0.86 + 0.05 * np.sin(angulo * 2.0 + 0.7) + 0.035 * np.sin(angulo * 3.0 + 2.1) + 0.02 * np.sin(angulo * 5.0 + 4.0)
    medio = _ruido_suave(rng, LADO, 10) - 0.5
    fino = _ruido_suave(rng, LADO, 90) - 0.5
    borda = torto + medio * 0.12
    alfa = np.clip((borda - raio) / 0.08 + 0.5 + fino * 0.9, 0.0, 1.0)
    alfa = alfa * alfa * (3.0 - 2.0 * alfa)
    rgb = terra[..., :3] * (1.0 + 0.06 * np.clip(1.0 - raio / 0.7, 0.0, 1.0))[..., None]
    gravar(np.concatenate([np.clip(rgb, 0.0, 1.0), alfa[..., None]], axis=-1), destino)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--somente", default="")
    parser.add_argument("--bruto-sufixo", default="")
    parser.add_argument("--previas", default=str(PROJECT / ".assets-raw/openai/texturas_chao/previas"))
    parser.add_argument("--so-previa", action="store_true", help="grava só a prévia, sem tocar em assets/")
    args = parser.parse_args()
    previas = Path(args.previas)
    previas.mkdir(parents=True, exist_ok=True)
    somente = {s for s in args.somente.split(",") if s}
    for bruto in sorted(BRUTOS.glob(f"*{args.bruto_sufixo}.png")):
        id_ = bruto.stem[: len(bruto.stem) - len(args.bruto_sufixo)] if args.bruto_sufixo else bruto.stem
        if somente and id_ not in somente:
            continue
        if not args.bruto_sufixo and "_" in bruto.stem and bruto.stem.endswith("_semi_realista"):
            continue
        rgba = preparar(bruto, ACHATAR.get(id_, 128.0))
        previa(rgba, previas / f"{bruto.stem}_3x3.jpg")
        media = (rgba[..., :3].reshape(-1, 3).mean(axis=0) * 255.0).round().astype(int)
        if args.so_previa:
            print(f"{bruto.stem}: prévia, média sRGB {tuple(media)}")
            continue
        destino = SAIDA / f"{id_}_v1.png"
        gravar(rgba, destino)
        print(f"{destino.relative_to(PROJECT)}: média sRGB {tuple(media)}")
        if id_ == "terra_batida_varrida":
            terreiro = SAIDA / "terreiro_varrido_v1.png"
            terreiro_varrido(rgba, terreiro)
            print(f"{terreiro.relative_to(PROJECT)}: terreiro oval")


if __name__ == "__main__":
    main()
