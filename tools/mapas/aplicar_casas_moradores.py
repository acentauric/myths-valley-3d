"""Aplica as casas dos moradores novos e o quintal de cada casa na composicao_vale.tscn.

Só acrescenta e corrige blocos de nó no texto da cena: não regrava a cena pelo
Godot sem tela, que tiraria os UIDs e congelaria as propriedades dos Terreiros
(o mesmo trato do aplicar_bioma_orla.py). Rodar de novo não duplica nada:

  1. AS CASAS NOVAS (tabela CASAS abaixo, os lotes A–H do relatório dos
     moradores, medidos pela regra do `_lote_na_rua`) entram antes do bloco da
     Igreja, cada uma com o Terreiro dela. Nenhuma se chama "Casa do arraial…":
     esse nome entra na escolha das casas do Pedro e da Zefa
     (`world_builder._escolher_as_casas_dos_moradores`).
  2. O MODELO DE DUAS CASAS ANTIGAS muda (TROCAR): a casa paroquial do padre na
     Casa do arraial 7 e a casa ocre do sacristão na 1. As de taipa (#6, #8 e a
     herdada) não mudam: os cômodos são medidos na casca delas.
  3. O QUINTAL (varal, pitangueira das casas novas, galinheiro, chiqueiro e
     cocho) vem de tools/mapas/casas_moradores_plano.json, que o
     planejar_casas_moradores.gd escreve medindo o vale montado: cada peça
     entra logo depois do Terreiro da casa, e a que já existe só tem a posição
     corrigida. Nunca no fim do arquivo, onde a orla acrescenta os Avulsos.

Recarregue a cena no editor SEM salvar antes.

    python tools/mapas/aplicar_casas_moradores.py
    godot --headless --path . --script res://tools/mapas/planejar_casas_moradores.gd
    python tools/mapas/aplicar_casas_moradores.py
"""
import json
import math
import random
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
CENA = RAIZ / "scenes/prototipo_3d/composicao_vale.tscn"
PLANO = RAIZ / "tools/mapas/casas_moradores_plano.json"

## As casas novas: identificador, modelo, (x, y, z) do lote, giro (frente para a
## rua) e a largura do modelo, que dá o tamanho do Terreiro.
CASAS = [
    ("Casa do guarda", "casa_taipa_azul", (-29.5, 3.85, -7.0), 1.916, 6.5),
    ("Casa do pescador", "casa_pescador", (-31.2, 3.37, 21.6), 0.955, 5.8),
    ("Casa da marisqueira", "casa_meia_agua", (-5.0, 2.51, 42.2), -2.020, 5.2),
    ("Casa da lavadeira", "casa_taipa_rosa", (-14.4, 2.79, 59.0), -2.153, 6.5),
    ("Casa da rendeira", "casa_taipa_verde", (-44.8, 3.44, 30.4), -0.459, 6.5),
    ("Casa da quituteira", "casa_varanda", (-34.5, 3.12, 56.2), 0.959, 7.0),
    ("Casa do carpinteiro", "casa_taipa_ocre", (-56.9, 3.68, 26.3), -0.067, 6.5),
    ("Casa de farinha", "casa_farinha", (99.3, 4.08, -200.7), -2.077, 8.0),
]
## Casas antigas que trocam de modelo.
TROCAR = {
    "Casa do arraial 7": "casa_paroquial",
    "Casa do arraial 1": "casa_taipa_ocre",
}


def giro_y(giro, x, y, z):
    """Transform3D da cena (linhas da base) de um giro em Y."""
    c, s = math.cos(giro), math.sin(giro)
    v = [c, 0, s, 0, 1, 0, -s, 0, c, x, y, z]
    return "Transform3D(" + ", ".join(f"{n:.7g}" for n in v) + ")"


def main():
    texto = CENA.read_text(encoding="utf-8")
    blocos = re.split(r"\n(?=\[node )", texto)
    usados = set(int(u) for u in re.findall(r"unique_id=(\d+)", texto))
    sorteio = random.Random(18870513)

    def novo_id():
        while True:
            n = sorteio.randint(10_000_000, 2_000_000_000)
            if n not in usados:
                usados.add(n)
                return n

    def recurso(arquivo):
        return re.search(r'\[ext_resource [^\]]*' + re.escape(arquivo) + r'" id="([^"]+)"\]', texto).group(1)

    script_casa = recurso("casa_composicao.gd")
    script_peca = recurso("peca_composicao.gd")
    terreiro = recurso("terreiro_casa.tscn")

    def indice(nome, pai="Casas"):
        for i, b in enumerate(blocos):
            if re.match(rf'\[node name="{re.escape(nome)}"[^\]]*parent="{re.escape(pai)}"', b):
                return i
        return -1

    # 1. As casas novas, antes da Igreja.
    novas = 0
    for nome, chave, (x, y, z), giro, largura in CASAS:
        if indice(nome) >= 0:
            continue
        igreja = indice("Igreja")
        assert igreja >= 0, "a cena não tem a Igreja"
        casa = (f'[node name="{nome}" type="Node3D" parent="Casas" unique_id={novo_id()}]\n'
                f"transform = {giro_y(giro, x, y, z)}\n"
                f'script = ExtResource("{script_casa}")\n'
                f'identificador = "{nome}"\nchave = "{chave}"\n'
                f"posicao_inicial = Vector3({x}, {y}, {z})\n"
                f"posicao_lote_inicial = Vector3({x}, {round(y + 0.3, 3)}, {z})\n"
                "pecas_criadas = true\nmetadata/_edit_group_ = true\n")
        chao = (f'[node name="Terreiro" parent="Casas/{nome}" unique_id={novo_id()} instance=ExtResource("{terreiro}")]\n'
                "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.7, 0)\n"
                f"size = Vector3({round(largura + 3.2, 3)}, 2.4, {round(largura * 0.86 + 3.2, 3)})\n")
        blocos[igreja:igreja] = [casa, chao]
        novas += 1

    # 2. O modelo novo de duas casas antigas.
    trocadas = 0
    for nome, chave in TROCAR.items():
        i = indice(nome)
        if i < 0:
            continue
        trocado = re.sub(r'\nchave = "[^"]*"\n', f'\nchave = "{chave}"\n', blocos[i], count=1)
        if trocado != blocos[i]:
            blocos[i] = trocado
            trocadas += 1

    # 3. O quintal, do plano medido no vale.
    postas = movidas = 0
    plano = json.loads(PLANO.read_text(encoding="utf-8")) if PLANO.exists() else {"casas": {}}
    for nome, pecas in plano.get("casas", {}).items():
        pai = f"Casas/{nome}"
        if indice(nome) < 0:
            print(f"AVISO: a casa '{nome}' do plano não está na cena", file=sys.stderr)
            continue
        depois = indice("Terreiro", pai)
        if depois < 0:
            depois = indice(nome)
        for peca in pecas:
            forma = giro_y(peca["giro"], peca["x"], peca["y"], peca["z"])
            i = indice(peca["id"], pai)
            if i >= 0:
                corrigido = re.sub(r"\ntransform = Transform3D\([^)]*\)\n", f"\ntransform = {forma}\n", blocos[i], count=1)
                corrigido = re.sub(r'\nchave = "[^"]*"\n', f'\nchave = "{peca["chave"]}"\n', corrigido, count=1)
                if corrigido != blocos[i]:
                    blocos[i] = corrigido
                    movidas += 1
                depois = max(depois, i)
                continue
            bloco = (f'[node name="{peca["id"]}" type="Node3D" parent="{pai}" unique_id={novo_id()}]\n'
                     f"transform = {forma}\n"
                     f'script = ExtResource("{script_peca}")\n'
                     f'id = "{peca["id"]}"\n')
            if peca.get("tipo", "adereco") != "adereco":
                bloco += f'tipo = "{peca["tipo"]}"\n'
            bloco += f'chave = "{peca["chave"]}"\n'
            if abs(float(peca.get("tamanho", 1.0)) - 1.0) > 1e-6:
                bloco += f'tamanho = {peca["tamanho"]}\n'
            blocos.insert(depois + 1, bloco)
            depois += 1
            postas += 1

    saida = "\n".join(b if b.endswith("\n") else b + "\n" for b in blocos)
    saida = re.sub(r"\n{3,}", "\n\n", saida)
    ids = re.findall(r"unique_id=(\d+)", saida)
    assert len(ids) == len(set(ids)), "unique_id repetido"
    CENA.write_bytes(saida.encode("utf-8"))
    print(f"CASAS_DOS_MORADORES_APLICADAS: +{novas} casas, {trocadas} modelos trocados, +{postas} peças de quintal, {movidas} corrigidas")


if __name__ == "__main__":
    main()
