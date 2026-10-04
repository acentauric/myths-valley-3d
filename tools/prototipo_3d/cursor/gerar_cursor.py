"""Gera o cursor do jogo: seta e mão, em ouro com contorno de laca.

    python tools/prototipo_3d/cursor/gerar_cursor.py

O desenho é feito numa grade de 32 unidades, 8x maior, e reduzido para LADO
pixels: a borda sai lisa sem depender do filtro do Godot. O contorno escuro e a
sombra mantêm o cursor legível sobre céu claro e sobre a mata escura.

Os pontos quentes (a ponta da seta, a ponta do dedo) são impressos no fim e
precisam bater com os de `scripts/autoload/tela.gd`.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

GRADE = 32
LADO = 40
SUPER = 8
PX = LADO * SUPER
U = PX / GRADE

OURO_CLARO = (248, 228, 168)
OURO = (232, 196, 106)
OURO_ESCURO = (178, 128, 52)
LACA = (12, 20, 16)

DESTINO = Path(__file__).resolve().parents[3] / "assets" / "prototipo_3d" / "identidade"


def _u(pontos):
    return [(x * U, y * U) for x, y in pontos]


def _caixa(x0, y0, x1, y1):
    return [x0 * U, y0 * U, x1 * U, y1 * U]


def _gradiente():
    """Ouro claro no alto, ouro escuro embaixo, como a talha da moldura."""
    faixa = Image.new("RGB", (1, PX))
    for y in range(PX):
        t = y / (PX - 1)
        if t < 0.5:
            a, b, k = OURO_CLARO, OURO, t / 0.5
        else:
            a, b, k = OURO, OURO_ESCURO, (t - 0.5) / 0.5
        faixa.putpixel((0, y), tuple(round(a[i] + (b[i] - a[i]) * k) for i in range(3)))
    return faixa.resize((PX, PX))


def _compor(mascara: Image.Image, vincos=()) -> Image.Image:
    contorno = mascara.filter(ImageFilter.MaxFilter(int(U * 1.6) | 1))
    sombra = contorno.filter(ImageFilter.GaussianBlur(U * 0.9))
    sombra = ImageChops.offset(sombra, int(U * 0.7), int(U * 1.1)).point(lambda v: int(v * 0.45))

    imagem = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    imagem.paste(Image.new("RGBA", (PX, PX), (0, 0, 0, 255)), mask=sombra)
    imagem.paste(Image.new("RGBA", (PX, PX), LACA + (255,)), mask=contorno)
    imagem.paste(_gradiente().convert("RGBA"), mask=mascara)

    traco = ImageDraw.Draw(imagem)
    for linha in vincos:
        traco.line(_u(linha), fill=LACA + (255,), width=int(U * 0.9))
    return imagem.resize((LADO, LADO), Image.LANCZOS)


def seta() -> tuple[Image.Image, tuple[int, int]]:
    ponta = (3.0, 2.5)
    mascara = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(mascara).polygon(_u([
        ponta, (3.0, 24.0), (8.4, 19.0), (12.0, 27.2),
        (15.4, 25.7), (11.9, 17.8), (19.2, 17.8),
    ]), fill=255)
    return _compor(mascara), _quente(ponta)


def mao() -> tuple[Image.Image, tuple[int, int]]:
    ponta = (12.6, 2.0)
    mascara = Image.new("L", (PX, PX), 0)
    d = ImageDraw.Draw(mascara)
    raio = 2.6 * U
    d.rounded_rectangle(_caixa(10.0, 2.0, 15.2, 18.0), radius=raio, fill=255)   # indicador
    d.rounded_rectangle(_caixa(15.0, 10.6, 19.6, 18.0), radius=raio, fill=255)  # médio
    d.rounded_rectangle(_caixa(19.4, 12.0, 23.8, 19.0), radius=raio, fill=255)  # anelar
    d.rounded_rectangle(_caixa(23.4, 13.6, 27.4, 20.0), radius=raio * 0.9, fill=255)  # mínimo
    d.rounded_rectangle(_caixa(9.6, 14.0, 27.4, 29.0), radius=4.4 * U, fill=255)  # palma
    d.polygon(_u([(10.4, 16.6), (5.0, 13.4), (3.6, 15.4), (9.0, 23.0)]), fill=255)  # polegar
    d.ellipse(_caixa(3.0, 12.6, 6.6, 16.4), fill=255)
    vincos = [
        [(15.2, 13.0), (15.2, 17.4)],
        [(19.5, 14.2), (19.5, 18.2)],
        [(23.6, 15.6), (23.6, 19.2)],
    ]
    return _compor(mascara, vincos), _quente(ponta)


def _quente(ponto):
    return round(ponto[0] * LADO / GRADE), round(ponto[1] * LADO / GRADE)


if __name__ == "__main__":
    for nome, gerar in (("cursor_seta.png", seta), ("cursor_mao.png", mao)):
        imagem, quente = gerar()
        imagem.save(DESTINO / nome)
        print(f"{nome}: {LADO}x{LADO}, ponto quente {quente}")
