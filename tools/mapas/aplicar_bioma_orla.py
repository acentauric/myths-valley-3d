"""Aplica tools/mapas/bioma_orla_plano.json na composicao_vale.tscn.

Só acrescenta e reparenta blocos de nó no texto da cena: não regrava a cena pelo
Godot sem tela, que tiraria os UIDs e congelaria as propriedades dos Terreiros.

- Sem o grupo Avulsos/"Coqueiros da orla" (ou Avulsos/Manguezal) na cena, cria o
  grupo com o que o código sorteava (data/composicao/avulsos_padrao.json, gerado
  por semear_avulsos.gd), como o editor faria ao abrir a cena. Os outros grupos
  de Avulsos o editor cria sozinho (e, até lá, o jogo usa o código para eles).
- Cria "Coqueiros da orla"/Norte e /Sul, move os coqueiros existentes para o lado
  certo e acrescenta os coqueiros e os mangues novos do plano.

Recarregue a cena no editor SEM salvar antes.

    python tools/mapas/aplicar_bioma_orla.py
"""
import json
import math
import random
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
CENA = RAIZ / "scenes/prototipo_3d/composicao_vale.tscn"
PLANO = RAIZ / "tools/mapas/bioma_orla_plano.json"
SEMENTE = RAIZ / "data/composicao/avulsos_padrao.json"
AVULSOS = "Avulsos"
COQUEIROS = "Avulsos/Coqueiros da orla"
MANGUEZAL = "Avulsos/Manguezal"
DESCRICAO = ("Objetos fora das casas. Mova e gire (Y) à vontade; Ctrl+D acrescenta, apagar tira do jogo. "
             "Os subgrupos só organizam (Coqueiros da orla e Manguezal: o jogo planta os daqui no lugar dos sorteados).")


def transformacao(giro, x, y, z):
    c, s = math.cos(giro), math.sin(giro)
    v = [c, 0, -s, 0, 1, 0, s, 0, c, x, y, z]
    return "Transform3D(" + ", ".join(f"{n:.6g}" for n in v) + ")"


def main():
    texto = CENA.read_text(encoding="utf-8")
    plano = json.loads(PLANO.read_text(encoding="utf-8"))
    semente = json.loads(SEMENTE.read_text(encoding="utf-8")) if SEMENTE.exists() else {"avulsos": []}
    blocos = re.split(r"\n(?=\[node )", texto)
    usados = set(int(u) for u in re.findall(r"unique_id=(\d+)", texto))
    sorteio = random.Random(1887)

    def novo_id():
        while True:
            n = sorteio.randint(10_000_000, 2_000_000_000)
            if n not in usados:
                usados.add(n)
                return n

    peca = re.search(r'\[ext_resource type="Script"[^\]]*peca_composicao\.gd" id="([^"]+)"\]', texto).group(1)

    def tem_no(nome, pai):
        return any(re.match(rf'\[node name="{re.escape(nome)}"[^\]]*parent="{re.escape(pai)}"', b) for b in blocos)

    def bloco_grupo(nome, pai, descricao=None):
        extra = f'editor_description = "{descricao}"\n' if descricao else ""
        return f'[node name="{nome}" type="Node3D" parent="{pai}" unique_id={novo_id()}]\n{extra}'

    def bloco_peca(nome, pai, chave, giro, x, y, z, escala):
        return (f'[node name="{nome}" type="Node3D" parent="{pai}" unique_id={novo_id()}]\n'
                f"transform = {transformacao(giro, x, y, z)}\n"
                f'script = ExtResource("{peca}")\n'
                f'id = "{nome}"\ntipo = "arvore"\nchave = "{chave}"\ntamanho = {escala}\n')

    acrescentar = []  # blocos novos, no fim da cena (o pai sempre vem antes do filho)

    # 1. Avulsos e os dois grupos de vegetação, se a cena ainda não os tem.
    if not tem_no("Avulsos", "."):
        acrescentar.append(bloco_grupo("Avulsos", ".", DESCRICAO))
    sem_coqueiros = not tem_no("Coqueiros da orla", AVULSOS)
    sem_mangues = not tem_no("Manguezal", AVULSOS)
    if sem_coqueiros:
        acrescentar.append(bloco_grupo("Coqueiros da orla", AVULSOS))
    for lado in ("Norte", "Sul"):
        if not tem_no(lado, COQUEIROS):
            acrescentar.append(bloco_grupo(lado, COQUEIROS))
    if sem_mangues:
        acrescentar.append(bloco_grupo("Manguezal", AVULSOS))

    # 2. O que o código sorteava, para o grupo que faltava (a semente).
    n_coq = n_man = 0
    for it in semente.get("avulsos", []):
        grupo = it.get("grupo", "")
        pos = it["pos"]
        if grupo == "Coqueiros da orla" and sem_coqueiros:
            lado = plano["reagrupar"][it["id"]]
            acrescentar.append(bloco_peca(it["id"], f"{COQUEIROS}/{lado}", it["chave"], it["giro"], pos[0], pos[1], pos[2], it["tamanho"]))
        elif grupo == "Manguezal" and sem_mangues:
            acrescentar.append(bloco_peca(it["id"], MANGUEZAL, it["chave"], it["giro"], pos[0], pos[1], pos[2], it["tamanho"]))
        if grupo == "Coqueiros da orla":
            n_coq = max(n_coq, int(it["id"].rsplit(" ", 1)[1]))
        elif grupo == "Manguezal":
            n_man = max(n_man, int(it["id"].rsplit(" ", 1)[1]))

    # 3. Coqueiros que já estavam na cena soltos no grupo: para o lado certo.
    for i, b in enumerate(blocos):
        m = re.match(rf'\[node name="([^"]+)"([^\]]*)parent="{re.escape(COQUEIROS)}"', b)
        if m and m.group(1) in plano["reagrupar"]:
            blocos[i] = b.replace(f'parent="{COQUEIROS}"', f'parent="{COQUEIROS}/{plano["reagrupar"][m.group(1)]}"', 1)

    # 4. Novos, com numeração depois da maior existente (na cena ou na semente).
    def maior(prefixo):
        nums = [int(n) for n in re.findall(rf'\[node name="{prefixo} (\d+)"', "\n".join(blocos))]
        return max(nums) if nums else 0
    n_coq, n_man = max(n_coq, maior("Coqueiro da orla")), max(n_man, maior("Mangue"))
    novos_coq = novos_man = 0
    for c in plano["coqueiros"]:
        n_coq += 1
        novos_coq += 1
        acrescentar.append(bloco_peca(f"Coqueiro da orla {n_coq}", f'{COQUEIROS}/{c["lado"]}', "coqueiro", c["giro"], c["x"], c["y"], c["z"], c["escala"]))
    for m in plano["mangues"]:
        n_man += 1
        novos_man += 1
        acrescentar.append(bloco_peca(f"Mangue {n_man}", MANGUEZAL, "mangue", m["giro"], m["x"], m["y"], m["z"], m["escala"]))

    saida = "\n".join(b if b.endswith("\n") else b + "\n" for b in blocos)
    saida = saida.rstrip("\n") + "\n\n" + "\n".join(acrescentar)
    saida = re.sub(r"\n{3,}", "\n\n", saida)
    ids = re.findall(r"unique_id=(\d+)", saida)
    assert len(ids) == len(set(ids)), "unique_id repetido"
    nomes = re.findall(r'\[node name="([^"]+)"[^\]]*parent="Avulsos/(?:Coqueiros da orla/(?:Norte|Sul)|Manguezal)"', saida)
    assert len(nomes) == len(set(nomes)), "nome de avulso repetido"
    CENA.write_text(saida, encoding="utf-8")
    print(f"BIOMA_APLICADO: {len(plano['reagrupar'])} coqueiros reagrupados, +{novos_coq} coqueiros, +{novos_man} mangues"
          f" (grupos criados da semente: coqueiros={sem_coqueiros}, mangues={sem_mangues})")


if __name__ == "__main__":
    main()
