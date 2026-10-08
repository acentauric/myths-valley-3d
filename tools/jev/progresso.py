"""Quanto falta para zerar o jogo: progresso medido pelas cadeias de missão.

A fonte é o próprio estado observado (`mission_chains`, enviado pela ponte do Godot a
partir de `cadeia_de_missoes.gd`): cada cadeia de enredo (`main`) é um capítulo, e o
passo em curso (`step`) conta quantos passos dela já foram cumpridos. Nada aqui lê
arquivo de missão nem escolhe ação: só mede.
"""
from __future__ import annotations


def capitulos(state):
    """Capítulos da história implementada, na ordem em que o jogo os cadastra.

    Cada item: nome, passos feitos, passos totais, se começou e se acabou. Cadeias
    laterais (`main` falso) ficam de fora: o alvo é a história até `fazenda_chegada`.
    """
    resultado = []
    for cadeia in state.get("mission_chains", []) or []:
        if not cadeia.get("main"):
            continue
        total = max(0, int(cadeia.get("total", 0) or 0))
        if total == 0:
            continue
        passo = int(cadeia["step"]) if cadeia.get("step") is not None else -1
        feitos = total if cadeia.get("completed") else max(0, min(total, passo))
        resultado.append({"nome": str(cadeia.get("name", "")), "feitos": feitos, "total": total,
                          "comecou": bool(cadeia.get("started")), "acabou": bool(cadeia.get("completed")),
                          "trancada": bool(cadeia.get("locked"))})
    return resultado


def medir(state):
    """Resumo do progresso geral e do capítulo atual a partir de um estado."""
    lista = capitulos(state)
    total = sum(c["total"] for c in lista)
    feitos = sum(c["feitos"] for c in lista)
    atual = next((c for c in lista if c["comecou"] and not c["acabou"]), None)
    if atual is None:
        atual = next((c for c in lista if not c["acabou"] and not c["trancada"]), None)
    if atual is None and lista:
        atual = lista[-1]
    objetivo = state.get("objective", {}) or {}
    proximo = str(objetivo.get("resumo") or objetivo.get("linha") or objetivo.get("titulo") or "")
    return {"feitos": feitos, "total": total,
            "percentual": round(100.0 * feitos / total, 1) if total else 0.0,
            "capitulo": atual["nome"] if atual else "",
            "capitulo_feitos": atual["feitos"] if atual else 0,
            "capitulo_total": atual["total"] if atual else 0,
            "proximo_objetivo": proximo,
            "marcos": [{"nome": c["nome"], "feitos": c["feitos"], "total": c["total"],
                        "atual": c is atual, "acabou": c["acabou"]} for c in lista],
            "completa": bool(state.get("implemented_story_completed"))}


class Ritmo:
    """Ações e tempo de jogo por passo, e a estimativa até zerar no ritmo atual."""

    def __init__(self):
        self.acoes = 0
        self.ultimo_feitos = None
        self.ultimo_marco = (0, 0.0)
        self.passos = []          # um item por avanço: ações, segundos e quem destravou
        self.curva = []           # (ações, segundos, percentual) a cada avanço
        self.mais_distante = {"feitos": 0, "percentual": 0.0, "acoes": 0, "segundos": 0.0,
                              "capitulo": "", "capitulo_feitos": 0, "capitulo_total": 0}
        self.por_capitulo = {}    # nome -> {"deterministic": n, "jev": n, "gpt": n}

    def contar_acao(self):
        self.acoes += 1

    def observar(self, progresso, segundos, destravou="deterministic"):
        """Registra o progresso; devolve o passo novo quando algum foi cumprido."""
        feitos = progresso["feitos"]
        if self.ultimo_feitos is None:
            self.ultimo_feitos = feitos
            self.ultimo_marco = (self.acoes, float(segundos))
            if feitos > self.mais_distante["feitos"]:
                self._marcar_distante(progresso, segundos)
            return None
        if feitos <= self.ultimo_feitos:
            return None
        novos = feitos - self.ultimo_feitos
        acoes = self.acoes - self.ultimo_marco[0]
        tempo = float(segundos) - self.ultimo_marco[1]
        passo = {"passos": novos, "acoes": acoes, "segundos": round(tempo, 1), "destravou": destravou,
                 "capitulo": progresso["capitulo"], "feitos": feitos}
        self.passos.append(passo)
        contagem = self.por_capitulo.setdefault(progresso["capitulo"], {})
        contagem[destravou] = contagem.get(destravou, 0) + novos
        self.curva.append((self.acoes, round(float(segundos), 1), progresso["percentual"]))
        self.ultimo_feitos = feitos
        self.ultimo_marco = (self.acoes, float(segundos))
        if feitos > self.mais_distante["feitos"]:
            self._marcar_distante(progresso, segundos)
        return passo

    def _marcar_distante(self, progresso, segundos):
        self.mais_distante = {"feitos": progresso["feitos"], "percentual": progresso["percentual"],
                              "acoes": self.acoes, "segundos": round(float(segundos), 1),
                              "capitulo": progresso["capitulo"], "capitulo_feitos": progresso["capitulo_feitos"],
                              "capitulo_total": progresso["capitulo_total"]}

    def estimativa(self, progresso):
        """Média de ações/tempo por passo cumprido e o que falta nesse ritmo."""
        feitos_passos = sum(p["passos"] for p in self.passos)
        faltam = max(0, progresso["total"] - progresso["feitos"])
        if feitos_passos == 0:
            return {"acoes_por_passo": None, "segundos_por_passo": None,
                    "acoes_restantes": None, "segundos_restantes": None, "passos_restantes": faltam}
        acoes = sum(p["acoes"] for p in self.passos) / feitos_passos
        segundos = sum(p["segundos"] for p in self.passos) / feitos_passos
        return {"acoes_por_passo": round(acoes, 1), "segundos_por_passo": round(segundos, 1),
                "acoes_restantes": int(round(acoes * faltam)), "segundos_restantes": int(round(segundos * faltam)),
                "passos_restantes": faltam}

    def resumo(self, progresso):
        return {"progresso": progresso, "ritmo": self.estimativa(progresso), "acoes": self.acoes,
                "mais_distante": dict(self.mais_distante), "curva": [list(p) for p in self.curva],
                "passos": list(self.passos),
                "destravado_por_capitulo": {k: dict(v) for k, v in self.por_capitulo.items()}}
