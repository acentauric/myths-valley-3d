"""O ICONE DO JOGO (#230), feito do M do logotipo da identidade.

    python tools/prototipo_3d/icone/gerar_icone.py

Le assets/prototipo_3d/identidade/logo_myths_valley.png, recorta o M dourado do fundo (GrabCut: o
logotipo tem um brilho marrom atras das letras), e o poe numa pastilha de laca escura com filete de ouro,
a mesma paleta do menu. Grava em assets/prototipo_3d/identidade/icone/:

    icone.png   512x512  application/config/icon (janela e barra de tarefas do Godot)
    icone.ico   16, 24, 32, 48, 64, 128 e 256 px (quadros BMP)  windows_native_icon e application/icon da exportacao

Nao gasta credito: e recorte e composicao. Precisa de: pip install pillow numpy opencv-python
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parents[3]
LOGO = RAIZ / "assets/prototipo_3d/identidade/logo_myths_valley.png"
SAIDA = RAIZ / "assets/prototipo_3d/identidade/icone"

# O M ocupa a esquerda do logotipo: x de 0 a ~280, y de 0 a ~295 (com o floreio de baixo).
CAIXA_DO_M = (0, 0, 284, 300)
MARGEM = 24  # folga ao redor do recorte, para o GrabCut ter fundo de todos os lados
MESTRE = 1024  # compoe em 1024 e reduz: borda e filete sem serrilhado
ICO_TAMANHOS = [16, 24, 32, 48, 64, 128, 256]


def recortar_o_m() -> Image.Image:
    """O M do logotipo com fundo transparente."""
    fonte = cv2.imread(str(LOGO))
    if fonte is None:
        raise SystemExit(f"nao abri {LOGO}")
    x0, y0, x1, y1 = CAIXA_DO_M
    cortada = fonte[y0:y1, x0:x1]
    com_folga = cv2.copyMakeBorder(cortada, MARGEM, MARGEM, MARGEM, MARGEM, cv2.BORDER_REPLICATE)
    alto, largo = com_folga.shape[:2]
    mascara = np.full((alto, largo), cv2.GC_PR_BGD, np.uint8)
    mascara[: MARGEM + 2, :] = cv2.GC_BGD
    mascara[:, : MARGEM - 6] = cv2.GC_BGD
    mascara[:, largo - MARGEM + 6:] = cv2.GC_BGD
    mascara[alto - MARGEM + 2:, :] = cv2.GC_BGD
    mascara[MARGEM + 10: alto - MARGEM - 10, MARGEM + 10: largo - MARGEM - 10] = cv2.GC_PR_FGD
    cv2.grabCut(com_folga, mascara, None, np.zeros((1, 65)), np.zeros((1, 65)), 8, cv2.GC_INIT_WITH_MASK)
    opaco = np.where((mascara == cv2.GC_FGD) | (mascara == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    opaco = cv2.GaussianBlur(opaco, (0, 0), 0.8)
    rgba = cv2.cvtColor(com_folga, cv2.COLOR_BGR2RGBA)
    rgba[..., 3] = opaco
    imagem = Image.fromarray(rgba)
    return imagem.crop(imagem.getchannel("A").getbbox())


def pastilha(m: Image.Image) -> Image.Image:
    """A pastilha 1024x1024: laca escura, brilho dourado leve atras do M, filete de ouro."""
    t = MESTRE
    raio = int(t * 0.2)
    # Laca: o verde-preto do menu (0.04, 0.07, 0.06), mais claro no centro.
    ys, xs = np.mgrid[0:t, 0:t]
    dist = np.sqrt((xs - t / 2) ** 2 + (ys - t * 0.46) ** 2) / (t * 0.7)
    fundo = np.clip(1.0 - dist, 0, 1)[..., None]
    borda = np.array([8, 14, 12], float)
    centro = np.array([30, 40, 30], float)
    laca = (borda + (centro - borda) * fundo ** 1.4).astype(np.uint8)
    base = Image.fromarray(laca).convert("RGBA")

    # O brilho quente atras da letra, bem sutil.
    brilho = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    ImageDraw.Draw(brilho).ellipse([t * 0.2, t * 0.2, t * 0.8, t * 0.8], fill=(214, 150, 40, 70))
    base = Image.alpha_composite(base, brilho.filter(ImageFilter.GaussianBlur(t * 0.07)))

    # O M, ajustado a 66% da pastilha e centrado pelo peso do desenho (o floreio puxa a base para a esquerda).
    alvo = int(t * 0.66)
    escala = alvo / max(m.size)
    m = m.resize((round(m.width * escala), round(m.height * escala)), Image.LANCZOS)
    sombra = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    px = (t - m.width) // 2 + int(t * 0.01)
    py = (t - m.height) // 2
    sombra.paste((0, 0, 0, 150), (px + int(t * 0.008), py + int(t * 0.014)), m.getchannel("A"))
    base = Image.alpha_composite(base, sombra.filter(ImageFilter.GaussianBlur(t * 0.012)))
    camada = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    camada.paste(m, (px, py), m)
    base = Image.alpha_composite(base, camada)

    # O filete de ouro, dentro da borda arredondada.
    filete = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    desenho = ImageDraw.Draw(filete)
    inset = int(t * 0.035)
    desenho.rounded_rectangle([inset, inset, t - inset - 1, t - inset - 1], radius=raio - inset,
                              outline=(201, 150, 52, 255), width=max(4, int(t * 0.012)))
    base = Image.alpha_composite(base, filete)

    # Cantos arredondados, com transparencia fora.
    corte = Image.new("L", (t, t), 0)
    ImageDraw.Draw(corte).rounded_rectangle([0, 0, t - 1, t - 1], radius=raio, fill=255)
    base.putalpha(corte)
    return base


def main() -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)
    mestre = pastilha(recortar_o_m())
    icone = mestre.resize((512, 512), Image.LANCZOS)
    icone.save(SAIDA / "icone.png", optimize=True)
    # Cada tamanho sai do mestre, e nao de uma reducao do 256: o 16 e o 32 ficam nitidos.
    # Quadros em BMP (DIB) e nao em PNG: e o que todo leitor de icone entende, em qualquer tamanho. O System.Drawing,
    # por exemplo, desenha ruido no 32x32 de um .ico com quadros PNG.
    mestre.save(SAIDA / "icone.ico", format="ICO", sizes=[(s, s) for s in ICO_TAMANHOS], bitmap_format="bmp")
    print("icone.png 512x512 e icone.ico", ICO_TAMANHOS, "em", SAIDA)


if __name__ == "__main__":
    main()
