"""Escada de decisão do testador: determinístico, depois Jev, depois GPT, depois bloqueio.

O determinístico (`robo.py`) joga sozinho. Esta camada só observa se ele travou e, quando
trava, sobe um degrau de cada vez: recuperação local barata, plano curto do Jev, plano
curto do GPT, e por fim o registro do bloqueio. Quem fala com as APIs é `jogar.py`, que
guarda as chaves e o orçamento; aqui moram as regras, e por isso tudo roda sem rede e sem
custo nos testes (`test_escada.py`).

Sinais de "travado" (qualquer um sobe o degrau):

- o passo da missão e o contador (`2/3`), o inventário e as obras não mudam por N ações
  ou T segundos de jogo;
- laço de posição: o jogador fica num raio pequeno por muitas ações;
- recusas repetidas: o mesmo aviso ("Precisa de Machado.") aparece de novo;
- a dica do E aponta para um morador que a missão não pede, por muitas ações;
- `possible_stuck` do vigia do controlador.

Os três últimos são sinais leves: só valem depois de algumas ações sem progresso, para um
aviso solto não custar uma chamada.
"""
from __future__ import annotations

from collections import Counter, deque
import json
import math
import time

DETERMINISTICO = "deterministic"
JEV = "jev"
GPT = "gpt"
NIVEIS_IA = (JEV, GPT)

LIMITES = {
    "acoes": 25,                 # ações sem progresso até o primeiro sinal
    "segundos": 90.0,            # segundos de jogo sem progresso até o primeiro sinal
    "raio": 6.0,                 # laço de posição: raio em metros
    "janela_laco": 20,           # ... e quantas ações seguidas dentro dele
    "recusas": 2,                # o mesmo aviso, quantas vezes
    "alvo_acoes": 15,            # E mirando quem a missão não pede, por quantas ações
    "minimo_sinal_leve": 8,      # ações sem progresso antes de um sinal leve valer
    "local_acoes": 12,           # ações da recuperação local antes de chamar IA
    "entre_escalonamentos": 15.0,  # segundos reais mínimos entre dois pedidos de IA
    "chamadas_jev": 2,           # por passo da missão
    "chamadas_gpt": 1,           # por passo da missão
    "plano_maximo": 5,           # ações de um plano
}

RECUSAS_CAMINHO = "/Aviso"       # onde o HUD escreve "Precisa de Machado."


def inventario(state):
    itens = Counter()
    for espaco in (state.get("inventory", {}) or {}).get("slots", []) or []:
        item = espaco.get("id", espaco.get("item", ""))
        if item:
            itens[item] += int(espaco.get("qtd", espaco.get("quantidade", espaco.get("q", 1))))
    return dict(sorted(itens.items()))


def assinatura(state):
    """O que conta como progresso: passo e contador, cadeias, inventário, obras, golpes."""
    objetivo = state.get("objective", {}) or {}
    cadeias = [(c.get("name"), c.get("step")) for c in state.get("mission_chains", []) or []]
    return json.dumps([objetivo.get("id"), objetivo.get("feito"), cadeias, inventario(state),
                       state.get("built_works", {}), state.get("resource_work", {})], sort_keys=True)


def _distancia_plana(a, b):
    return math.hypot(a[0] - b[0], a[2] - b[2])


class DetectorDeTrava:
    """Conta ações sem progresso e reconhece os sinais de que o determinístico travou."""

    def __init__(self, limites=None):
        self.limites = {**LIMITES, **(limites or {})}
        self.assinatura = None
        self.reiniciar(0.0)
        self.ultimo_achado = None

    def reiniciar(self, agora):
        self.acoes = 0
        self.desde = float(agora)
        self.posicoes = deque(maxlen=self.limites["janela_laco"])
        self.recusas = Counter()
        self.mensagens_atuais = set()
        self.alvo_diferente = 0

    def observar(self, state, resultado="", task=None):
        """Uma observação por decisão. Devolve {"progresso": bool, "sinais": [...]}."""
        if "position" not in state:
            return {"progresso": False, "sinais": []}   # abertura e carga: nada a medir
        agora = float(state.get("seconds", 0))
        atual = assinatura(state)
        if self.assinatura is not None and atual != self.assinatura:
            self.assinatura = atual
            self.reiniciar(agora)
            self.mensagens_atuais = self._avisos(state)
            return {"progresso": True, "sinais": []}
        if self.assinatura is None:
            self.assinatura = atual
            self.desde = agora
        self.acoes += 1
        self.posicoes.append(state["position"])
        mensagens = self._avisos(state)
        for texto in mensagens - self.mensagens_atuais:
            self.recusas[texto] += 1     # só conta quando o aviso APARECE de novo
        self.mensagens_atuais = mensagens
        self._contar_alvo(state, task or {})
        return {"progresso": False, "sinais": self._sinais(state, agora, resultado)}

    @staticmethod
    def _avisos(state):
        return {str(o.get("text", "")).strip() for o in state.get("observations", []) or []
                if RECUSAS_CAMINHO in str(o.get("path", "")) and str(o.get("text", "")).strip()}

    def _contar_alvo(self, state, task):
        """A dica do E aponta para um morador que o passo não pede."""
        alvo = str(state.get("interaction_target", ""))
        if not alvo:
            return
        nomes = {str(n.get("name", "")): str(n.get("id", "")) for n in state.get("npcs", []) or []}
        nomes["Pedro"] = "pedro"
        if alvo not in nomes:
            return          # a dica é de um recurso ou da casa: não é conversa
        passo = task.get("step", {}) or {}
        meta = passo.get("meta", {}) or {}
        pedido = str(meta.get("a_quem", ""))
        if pedido:
            diferente = nomes[alvo] != pedido and alvo != pedido
        else:
            conversa = str(meta.get("tipo", "")) in ("falar", "levar", "seguir") or bool(passo.get("conduz"))
            diferente = bool(passo) and not conversa
        self.alvo_diferente = self.alvo_diferente + 1 if diferente else 0

    def _sinais(self, state, agora, resultado):
        limites = self.limites
        duros, leves = [], []
        if self.acoes >= limites["acoes"]:
            duros.append({"tipo": "sem_progresso_acoes", "detalhe": f"{self.acoes} ações"})
        if agora - self.desde >= limites["segundos"]:
            duros.append({"tipo": "sem_progresso_tempo", "detalhe": f"{int(agora - self.desde)} s de jogo"})
        achados = state.get("possible_issues", []) or []
        chave = json.dumps(achados[-1], sort_keys=True) if achados else None
        if (resultado == "possible_stuck_requires_review"
                or (chave is not None and chave != self.ultimo_achado
                    and (achados[-1] or {}).get("type") == "possible_stuck")):
            duros.append({"tipo": "possivel_travamento", "detalhe": "vigia do controlador"})
        self.ultimo_achado = chave
        if len(self.posicoes) == self.posicoes.maxlen:
            centro = [sum(p[i] for p in self.posicoes) / len(self.posicoes) for i in range(3)]
            if all(_distancia_plana(p, centro) <= limites["raio"] for p in self.posicoes):
                leves.append({"tipo": "laco_de_posicao",
                              "detalhe": f"{len(self.posicoes)} ações num raio de {limites['raio']:g} m"})
        repetida = [t for t, n in self.recusas.items() if n >= limites["recusas"]]
        if repetida:
            leves.append({"tipo": "recusa_repetida", "detalhe": repetida[0]})
        if self.alvo_diferente >= limites["alvo_acoes"]:
            leves.append({"tipo": "alvo_do_e_diferente", "detalhe": str(state.get("interaction_target", ""))})
        if self.acoes >= limites["minimo_sinal_leve"]:
            return duros + leves
        return duros


# Resultados do controlador que contam como ação que falhou (#239), além dos planos que falharam.
RESULTADOS_DE_FALHA = ("fail", "blocked", "stuck", "refus", "no_navigation", "no_walkable", "locked", "unavailable")


def acoes_que_falharam(historico, falhos):
    """{ação: vezes} das ações que já falharam neste passo: planos falhos e resultados de falha."""
    contagem = Counter()
    for falho in falhos or []:
        for acao in falho.get("plan", []) or []:
            contagem[acao] += 1
    for h in list(historico or [])[-10:]:
        resultado = str(h.get("result", "")).lower()
        if h.get("action") and any(marca in resultado for marca in RESULTADOS_DE_FALHA):
            contagem[h["action"]] += 1
    return dict(contagem.most_common())


def contexto_enxuto(state, actions, task, historico, sinais, recusas, falhos, nivel):
    """O que o Jev/GPT recebem: só o necessário para um plano curto, nunca o estado inteiro."""
    objetivo = state.get("objective", {}) or {}
    passo = (task or {}).get("step", {}) or {}
    perto = []
    for n in state.get("npcs", []) or []:
        if n.get("distance", 999) <= 20:
            perto.append({"name": n.get("name"), "node": n.get("node"), "distance": n.get("distance")})
    return {
        "role": nivel,
        "goal": "Destravar o passo atual da missão para seguir até o fim da história implementada (fazenda_chegada).",
        "step": {"objective_id": objetivo.get("id"), "title": objetivo.get("titulo"),
                 "summary": objetivo.get("resumo") or objetivo.get("linha"),
                 "counter": f"{objetivo.get('feito', 0)}/{objetivo.get('total', 0)}",
                 "chain": (task or {}).get("mission"), "requirement": passo.get("meta", {})},
        "inventory": inventario(state), "in_hand": (state.get("inventory", {}) or {}).get("in_hand"),
        "position": state.get("position"), "clock": (state.get("clock", {}) or {}).get("time"),
        "interior": state.get("interior"),
        "interaction_target": state.get("interaction_target"),
        "required_npc": (task or {}).get("required_npc", {}),
        "resource_targets": state.get("resource_targets", {}),
        "nearby_npcs": perto,
        "recent_actions": [{"action": h.get("action"), "result": h.get("result")} for h in list(historico)[-10:]],
        "refusals": sorted(recusas),
        "stuck_signals": sinais,
        "failed_plans": falhos,
        "failed_actions": acoes_que_falharam(historico, falhos),
        "do_not_repeat": "The actions in failed_actions already failed here (with how many times). Do NOT repeat them; "
                         "a plan made only of failed actions is rejected. Choose different actions.",
        "available_actions": sorted(actions),
    }


def plano_simulado(task, actions):
    """Plano local para a validação sem crédito (`--escada-simulada`): nenhuma API é chamada.

    Segue as ações que casam com o requisito e, depois, uma saída física livre. Serve para
    ver a escada, o painel e o relatório funcionando; não mede a inteligência do Jev nem
    do GPT."""
    plano = []
    for acao in (task or {}).get("actions_matching_the_current_requirement", []) or []:
        if acao in actions:
            plano.append(acao)
    for acao in (task or {}).get("recovery_options", []) or []:
        if acao in actions and acao not in plano:
            plano.append(acao)
    if not plano:
        plano = [a for a in actions if a.startswith("walk_")][:2] or ([next(iter(actions))] if actions else [])
    return plano[:3]


class Escada:
    """Máquina de estados do escalonamento. Não faz chamadas nem lê relógio de parede."""

    def __init__(self, ia=(), limites=None, relogio=time.monotonic, registrar=None):
        self.ia = tuple(n for n in NIVEIS_IA if n in ia)
        self.limites = {**LIMITES, **(limites or {})}
        self.detector = DetectorDeTrava(self.limites)
        self.relogio = relogio
        self.registrar = registrar or (lambda tipo, **dados: None)
        self.fase = "normal"          # normal | local | plano | escalar | sem_ia | bloqueado
        self.passo = None
        self.chamadas = Counter()     # por nível, no passo atual
        self.barrados = set()         # níveis negados neste passo (orçamento etc.)
        self.local_restante = 0
        self.plano = None
        self.proximo_nivel = None
        self.falhos = []
        self.aprendido = []
        self.escalonamentos = []
        self.sinais = []
        self.sinais_logados = ()
        self.ultimo_pedido = None
        self.nivel_da_ultima_acao = DETERMINISTICO

    # --- observação -------------------------------------------------------------
    def observar(self, state, resultado="", task=None):
        """Chamar uma vez por decisão, antes de `decidir`. Devolve o que mudou."""
        passo = (state.get("objective", {}) or {}).get("id")
        if "position" in state and passo != self.passo:
            self.passo = passo
            self.chamadas.clear()
            self.barrados.clear()
            self.falhos = []
        observacao = self.detector.observar(state, resultado, task)
        destravou = None
        if observacao["progresso"]:
            destravou = self._progrediu()
        self.sinais = observacao["sinais"]
        tipos = tuple(s["tipo"] for s in self.sinais)
        if tipos != self.sinais_logados:
            self.sinais_logados = tipos
            if tipos:
                self.registrar("stuck_signal", sinais=self.sinais, fase=self.fase,
                               acoes_sem_progresso=self.detector.acoes)
        return {"progresso": observacao["progresso"], "destravou": destravou}

    def _progrediu(self):
        destravou = DETERMINISTICO
        if self.fase == "plano" and self.plano and self.plano["executadas"] >= 1:
            destravou = self.plano["nivel"]
            padrao = {"sinais": [s["tipo"] for s in self.plano["sinais"]], "passo": self.plano["passo"],
                      "nivel": self.plano["nivel"], "plano": self.plano["acoes"]}
            self.aprendido.append(padrao)
            self.registrar("learned_pattern", **padrao)
            self.registrar("escalation_result", nivel=self.plano["nivel"], resultado="destravou")
        elif self.fase == "local":
            self.registrar("local_recovery_result", resultado="destravou")
        self.fase = "normal"
        self.plano = None
        self.proximo_nivel = None
        self.local_restante = 0
        self.falhos = []
        return destravou

    # --- decisão ------------------------------------------------------------------
    def decidir(self, state, actions, task, historico=()):
        """Devolve o que fazer agora. Pode ser chamada de novo depois de `resposta`/`falha`."""
        for _ in range(6):
            if self.fase == "bloqueado":
                return {"tipo": "bloqueio", "detalhe": self._bloqueio(state, task)}
            if self.fase == "plano":
                plano = self.plano
                if plano["restantes"]:
                    acao = plano["restantes"][0]
                    if acao in actions:
                        plano["restantes"].pop(0)
                        plano["executadas"] += 1
                        self.nivel_da_ultima_acao = plano["nivel"]
                        return {"tipo": "plano", "acao": acao, "nivel": plano["nivel"],
                                "indice": plano["executadas"], "total": len(plano["acoes"]),
                                "motivo": plano["motivo"]}
                    self._plano_falhou(f"acao_indisponivel:{acao}")
                else:
                    self._plano_falhou("sem_progresso_apos_o_plano")
                continue
            if self.fase == "escalar":
                resposta = self._escalar(state, actions, task, historico)
                if resposta is not None:
                    return resposta
                continue
            if self.fase == "local":
                self.local_restante -= 1
                if self.local_restante <= 0 and self.sinais:
                    self._depois_do_local()
                    continue
            elif self.fase == "normal" and self.sinais:
                self.fase = "local"
                self.local_restante = self.limites["local_acoes"]
                self.registrar("local_recovery", sinais=self.sinais, acoes=self.limites["local_acoes"])
            self.nivel_da_ultima_acao = DETERMINISTICO
            modo = "recuperacao_local" if self.fase in ("local", "sem_ia") else "normal"
            return {"tipo": "deterministico", "modo": modo, "sinais": self.sinais}
        return {"tipo": "deterministico", "modo": "normal", "sinais": self.sinais}

    def _depois_do_local(self):
        proximo = self._seguinte(None)
        if proximo is None:
            self.fase = "sem_ia"
            self.registrar("escalation_unavailable", motivo="nenhum apoio marcado ou disponível" if not self.ia else "limites do passo")
        else:
            self.fase = "escalar"
            self.proximo_nivel = proximo

    def _seguinte(self, depois_de, repetir=False):
        """O próximo degrau permitido: o mesmo, se repetir e couber; senão o de cima."""
        teto = {JEV: self.limites["chamadas_jev"], GPT: self.limites["chamadas_gpt"]}
        livres = [n for n in self.ia if n not in self.barrados and self.chamadas[n] < teto[n]]
        if repetir and depois_de in livres:
            return depois_de
        ordem = list(NIVEIS_IA)
        acima = ordem[ordem.index(depois_de) + 1:] if depois_de in ordem else ordem
        for nivel in acima:
            if nivel in livres:
                return nivel
        return None

    def _escalar(self, state, actions, task, historico):
        nivel = self.proximo_nivel
        if nivel is None:
            if self.falhos:
                self.fase = "bloqueado"
            else:
                self.fase = "sem_ia"
            return None
        agora = self.relogio()
        if self.ultimo_pedido is not None and agora - self.ultimo_pedido < self.limites["entre_escalonamentos"]:
            self.nivel_da_ultima_acao = DETERMINISTICO
            return {"tipo": "deterministico", "modo": "recuperacao_local", "sinais": self.sinais,
                    "aguardando": nivel}
        recusas = [t for t, n in self.detector.recusas.items() if n >= 1]
        contexto = contexto_enxuto(state, actions, task, historico, self.sinais, recusas, self.falhos, nivel)
        return {"tipo": "pedir", "nivel": nivel, "contexto": contexto, "sinais": self.sinais,
                "tentativa": self.chamadas[nivel] + 1}

    # --- respostas dos apoios -----------------------------------------------------------
    def resposta(self, nivel, acoes, motivo, state=None, custo=0.0):
        """O apoio devolveu um plano. Vazio ou além do limite conta como resposta inválida."""
        acoes = [a for a in acoes if isinstance(a, str)][: self.limites["plano_maximo"]]
        self.chamadas[nivel] += 1
        self.ultimo_pedido = self.relogio()
        self.escalonamentos.append({"nivel": nivel, "sinais": [s["tipo"] for s in self.sinais],
                                    "passo": self.passo, "custo": float(custo), "plano": acoes})
        self.registrar("escalation", nivel=nivel, sinais=self.sinais, passo=self.passo,
                       plano=acoes, motivo=motivo, custo_usd=float(custo), tentativa=self.chamadas[nivel])
        if not acoes:
            self.falha(nivel, "resposta_invalida", repetir=True, contar=False)
            return
        self.plano = {"nivel": nivel, "acoes": list(acoes), "restantes": list(acoes), "executadas": 0,
                      "motivo": motivo, "sinais": list(self.sinais), "passo": self.passo}
        self.fase = "plano"

    def falha(self, nivel, razao, repetir=False, contar=True):
        """Erro de API, resposta inválida: a chamada foi gasta e o plano não veio."""
        if contar:
            self.chamadas[nivel] += 1
            self.ultimo_pedido = self.relogio()
            self.registrar("escalation", nivel=nivel, sinais=self.sinais, passo=self.passo,
                           plano=[], motivo=razao, custo_usd=0.0, tentativa=self.chamadas[nivel])
        self.falhos.append({"level": nivel, "plan": [], "reason": razao})
        self.proximo_nivel = self._seguinte(nivel, repetir=repetir)
        self.fase = "escalar"

    def barrado(self, nivel, razao):
        """O freio negou a chamada (orçamento, chave): o degrau é pulado sem custo."""
        self.barrados.add(nivel)
        self.registrar("escalation_denied", nivel=nivel, motivo=razao, passo=self.passo)
        self.proximo_nivel = self._seguinte(nivel)
        self.fase = "escalar"
        if self.proximo_nivel is None and not self.falhos:
            self.fase = "sem_ia"

    def _plano_falhou(self, razao):
        plano = self.plano
        self.registrar("escalation_result", nivel=plano["nivel"], resultado="falhou", razao=razao)
        self.falhos.append({"level": plano["nivel"], "plan": plano["acoes"], "reason": razao})
        self.proximo_nivel = self._seguinte(plano["nivel"])
        self.plano = None
        self.fase = "escalar"

    def _bloqueio(self, state, task):
        return {"passo": self.passo, "posicao": state.get("position"),
                "sinais": self.sinais, "tentativas": list(self.falhos),
                "recusas": sorted(self.detector.recusas),
                "requisito": ((task or {}).get("step", {}) or {}).get("meta", {}),
                "inventario": inventario(state), "na_mao": (state.get("inventory", {}) or {}).get("in_hand")}

    def retomar(self, agora=0.0, motivo=""):
        """Depois do modal de bloqueio (#183): o humano devolveu o controle ou a rota alternativa
        começou. Zera a trava e volta ao normal; os tetos de chamadas do passo continuam valendo."""
        self.fase = "normal"
        self.plano = None
        self.proximo_nivel = None
        self.local_restante = 0
        self.falhos = []
        self.detector.assinatura = None
        self.detector.reiniciar(agora)
        self.sinais = []
        self.registrar("ladder_resumed", motivo=motivo, passo=self.passo)

    def resumo(self):
        return {"apoios": list(self.ia), "escalonamentos": list(self.escalonamentos),
                "aprendizado": list(self.aprendido), "fase": self.fase}
