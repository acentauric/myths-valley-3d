"""A escada Jev/GPT, o progresso até zerar e a detecção de apoios: tudo com respostas falsas.

Nenhum teste chama rede nem lê chave; `urlopen` e a sonda de rede são trocados por dublês.
"""
from decimal import Decimal
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from escada import DETERMINISTICO, GPT, JEV, DetectorDeTrava, Escada, contexto_enxuto, plano_simulado
from jogar import GPT_MODELO_PADRAO, Session, detectar_apoios, ler_ponteiro, ultima_sessao
from progresso import Ritmo, capitulos, medir


def estado(segundos=0, feito=1, posicao=(0.0, 0.0, 0.0), **extra):
    base = {"seconds": segundos, "position": list(posicao),
            "objective": {"id": "pedro_pedra", "feito": feito, "total": 3, "titulo": "Calçar o poço"},
            "inventory": {"slots": [], "in_hand": "picareta"}, "mission_chains": []}
    base.update(extra)
    return base


ACOES = {"walk_forward": "Walk", "walk_left": "Walk left", "interact": "Press E", "gather_pedra": "Pedra",
         "work_E": "Work", "wait": "Wait"}
TAREFA = {"step": {"meta": {"tipo": "juntar"}}, "mission": "Poço", "required_npc": {},
          "actions_matching_the_current_requirement": ["gather_pedra"], "recovery_options": ["walk_left"]}


class Relogio:
    def __init__(self):
        self.agora = 1000.0

    def __call__(self):
        return self.agora


def travar(escada, vezes, inicio=0, andar=False):
    """Roda `vezes` decisões sem progresso; devolve a última ação pedida pela escada."""
    resposta = None
    for i in range(vezes):
        posicao = (float(i % 40), 0.0, 0.0) if andar else (0.0, 0.0, 0.0)
        escada.observar(estado(inicio + i * 2, posicao=posicao), "", TAREFA)
        resposta = escada.decidir(estado(inicio + i * 2), ACOES, TAREFA)
    return resposta


class DetectorTests(unittest.TestCase):
    def test_no_progress_by_actions_raises_hard_signal(self):
        detector = DetectorDeTrava()
        sinais = []
        for i in range(26):
            sinais = detector.observar(estado(i, posicao=(i * 3.0, 0, 0)))["sinais"]
        self.assertIn("sem_progresso_acoes", [s["tipo"] for s in sinais])

    def test_no_progress_by_game_seconds(self):
        detector = DetectorDeTrava()
        detector.observar(estado(0))
        sinais = detector.observar(estado(95, posicao=(50, 0, 0)))["sinais"]
        self.assertIn("sem_progresso_tempo", [s["tipo"] for s in sinais])

    def test_counter_change_resets_everything(self):
        detector = DetectorDeTrava()
        for i in range(24):
            detector.observar(estado(i, feito=1, posicao=(i * 3.0, 0, 0)))
        self.assertTrue(detector.observar(estado(30, feito=2))["progresso"])
        self.assertEqual(detector.acoes, 0)

    def test_position_loop_needs_a_full_window_inside_the_radius(self):
        detector = DetectorDeTrava()
        tipos = []
        for i in range(20):
            tipos = [s["tipo"] for s in detector.observar(estado(i, posicao=(i % 3, 0, i % 2)))["sinais"]]
        self.assertIn("laco_de_posicao", tipos)

    def test_repeated_refusal_counts_appearances_not_frames(self):
        detector = DetectorDeTrava()
        aviso = {"observations": [{"path": "/root/Vale/HUD/Aviso/Rotulo", "text": "Precisa de Machado."}]}
        for i in range(10):          # o mesmo aviso na tela por vários quadros: uma só vez
            detector.observar(estado(i, posicao=(i * 3.0, 0, 0), **aviso))
        self.assertEqual(detector.recusas["Precisa de Machado."], 1)
        detector.observar(estado(11, posicao=(40, 0, 0)))
        sinais = detector.observar(estado(12, posicao=(45, 0, 0), **aviso))["sinais"]
        self.assertIn("recusa_repetida", [s["tipo"] for s in sinais])

    def test_light_signal_waits_for_a_few_actions_without_progress(self):
        detector = DetectorDeTrava()
        aviso = {"observations": [{"path": "/root/Vale/HUD/Aviso/Rotulo", "text": "Precisa de Machado."}]}
        detector.observar(estado(0, **aviso))
        detector.observar(estado(1))
        sinais = detector.observar(estado(2, posicao=(5, 0, 0), **aviso))["sinais"]
        self.assertEqual(sinais, [])

    def test_e_hint_on_the_wrong_villager_counts_only_when_the_step_is_not_about_people(self):
        detector = DetectorDeTrava()
        npcs = [{"name": "Pedro", "id": "pedro", "node": "MoradorPedro"}]
        for i in range(16):
            detector.observar(estado(i, posicao=(i * 3.0, 0, 0), interaction_target="Pedro", npcs=npcs), "", TAREFA)
        self.assertEqual(detector.alvo_diferente, 16)
        falar = {"step": {"meta": {"tipo": "falar", "a_quem": "pedro"}}}
        detector.alvo_diferente = 0
        detector.observar(estado(40, posicao=(1, 0, 0), interaction_target="Pedro", npcs=npcs), "", falar)
        self.assertEqual(detector.alvo_diferente, 0)

    def test_possible_stuck_from_the_controller_watchdog(self):
        detector = DetectorDeTrava()
        detector.observar(estado(0))
        sinais = detector.observar(estado(1, posicao=(9, 0, 0)), "possible_stuck_requires_review")["sinais"]
        self.assertIn("possivel_travamento", [s["tipo"] for s in sinais])


class EscadaTests(unittest.TestCase):
    def setUp(self):
        self.relogio = Relogio()
        self.eventos = []
        self.escada = Escada((JEV, GPT), relogio=self.relogio, registrar=lambda t, **d: self.eventos.append((t, d)))

    def travar_ate_pedir(self):
        resposta = None
        for i in range(120):
            self.escada.observar(estado(i * 2, posicao=(i * 3.0, 0, 0)), "", TAREFA)
            resposta = self.escada.decidir(estado(i * 2), ACOES, TAREFA)
            if resposta["tipo"] == "pedir":
                return resposta, i
        self.fail("a escada nunca pediu apoio")

    def test_deterministic_plays_alone_until_a_signal(self):
        resposta = travar(self.escada, 10, andar=True)
        self.assertEqual(resposta["tipo"], "deterministico")
        self.assertEqual(resposta["modo"], "normal")

    def test_first_signal_starts_cheap_local_recovery_before_any_paid_call(self):
        modos = []
        for i in range(40):
            self.escada.observar(estado(i * 2, posicao=(i * 3.0, 0, 0)), "", TAREFA)
            resposta = self.escada.decidir(estado(i * 2), ACOES, TAREFA)
            modos.append((resposta["tipo"], resposta.get("modo")))
        primeiro_pedido = next(i for i, (tipo, _) in enumerate(modos) if tipo == "pedir")
        self.assertGreaterEqual(primeiro_pedido, 25 + 12 - 1)
        self.assertIn(("deterministico", "recuperacao_local"), modos[:primeiro_pedido])

    def test_jev_plan_is_executed_and_progress_returns_control_and_learns(self):
        pedido, i = self.travar_ate_pedir()
        self.assertEqual(pedido["nivel"], JEV)
        self.assertIn("step", pedido["contexto"])
        self.escada.resposta(JEV, ["gather_pedra", "work_E"], "plano de teste")
        a = self.escada.decidir(estado(), ACOES, TAREFA)
        self.assertEqual((a["tipo"], a["acao"], a["nivel"]), ("plano", "gather_pedra", JEV))
        self.escada.observar(estado(500, posicao=(1, 0, 0)), "", TAREFA)
        b = self.escada.decidir(estado(), ACOES, TAREFA)
        self.assertEqual(b["acao"], "work_E")
        resultado = self.escada.observar(estado(502, feito=2), "", TAREFA)
        self.assertEqual(resultado["destravou"], JEV)
        c = self.escada.decidir(estado(), ACOES, TAREFA)
        self.assertEqual((c["tipo"], c["modo"]), ("deterministico", "normal"))
        self.assertEqual(self.escada.aprendido[0]["nivel"], JEV)
        self.assertIn(("learned_pattern", self.escada.aprendido[0]), self.eventos)

    def test_failed_jev_plan_escalates_to_gpt_with_the_failed_plan_in_context(self):
        self.travar_ate_pedir()
        self.escada.resposta(JEV, ["walk_left"], "tentativa")
        self.escada.decidir(estado(), ACOES, TAREFA)
        self.escada.observar(estado(600, posicao=(77, 0, 0)), "", TAREFA)
        self.relogio.agora += 60
        pedido = self.escada.decidir(estado(), ACOES, TAREFA)
        self.assertEqual((pedido["tipo"], pedido["nivel"]), ("pedir", GPT))
        self.assertEqual(pedido["contexto"]["failed_plans"][0]["plan"], ["walk_left"])

    def test_both_levels_failing_registers_a_block(self):
        self.travar_ate_pedir()
        self.escada.resposta(JEV, ["walk_left"], "x")
        self.escada.decidir(estado(), ACOES, TAREFA)
        self.escada.observar(estado(600, posicao=(77, 0, 0)), "", TAREFA)
        self.relogio.agora += 60
        self.assertEqual(self.escada.decidir(estado(), ACOES, TAREFA)["nivel"], GPT)
        self.escada.resposta(GPT, ["walk_forward"], "y")
        self.escada.decidir(estado(), ACOES, TAREFA)
        self.escada.observar(estado(700, posicao=(99, 0, 0)), "", TAREFA)
        self.relogio.agora += 60
        bloqueio = self.escada.decidir(estado(), ACOES, TAREFA)
        self.assertEqual(bloqueio["tipo"], "bloqueio")
        self.assertEqual(bloqueio["detalhe"]["passo"], "pedro_pedra")
        self.assertEqual(len(bloqueio["detalhe"]["tentativas"]), 2)

    def test_minimum_wait_between_escalations_keeps_the_deterministic_playing(self):
        self.travar_ate_pedir()
        self.escada.resposta(JEV, ["walk_left"], "x")
        self.escada.decidir(estado(), ACOES, TAREFA)
        self.escada.observar(estado(600, posicao=(77, 0, 0)), "", TAREFA)
        espera = self.escada.decidir(estado(), ACOES, TAREFA)      # o relógio não andou
        self.assertEqual(espera["tipo"], "deterministico")
        self.assertEqual(espera["aguardando"], GPT)

    def test_invalid_answer_repeats_the_same_level_until_the_step_cap(self):
        self.travar_ate_pedir()
        self.escada.falha(JEV, "resposta_invalida", repetir=True)
        self.relogio.agora += 60
        outra = self.escada.decidir(estado(), ACOES, TAREFA)
        self.assertEqual((outra["tipo"], outra["nivel"], outra["tentativa"]), ("pedir", JEV, 2))
        self.escada.falha(JEV, "resposta_invalida", repetir=True)    # 2 Jev é o teto por passo
        self.relogio.agora += 60
        self.assertEqual(self.escada.decidir(estado(), ACOES, TAREFA)["nivel"], GPT)

    def test_only_deterministic_never_escalates_and_never_blocks(self):
        escada = Escada((), relogio=self.relogio)
        for i in range(200):
            escada.observar(estado(i * 2, posicao=(i * 3.0, 0, 0)), "", TAREFA)
            resposta = escada.decidir(estado(i * 2), ACOES, TAREFA)
            self.assertEqual(resposta["tipo"], "deterministico")
        self.assertEqual(resposta["modo"], "recuperacao_local")

    def test_denied_budget_skips_the_level_without_blocking_when_nothing_was_tried(self):
        escada = Escada((JEV,), relogio=self.relogio)
        for i in range(60):
            escada.observar(estado(i * 2, posicao=(i * 3.0, 0, 0)), "", TAREFA)
            resposta = escada.decidir(estado(i * 2), ACOES, TAREFA)
            if resposta["tipo"] == "pedir":
                escada.barrado(JEV, "orcamento")
                resposta = escada.decidir(estado(i * 2), ACOES, TAREFA)
                self.assertEqual(resposta["tipo"], "deterministico")
                return
        self.fail("sem pedido")

    def test_new_mission_step_renews_the_per_step_caps(self):
        self.travar_ate_pedir()
        self.escada.falha(JEV, "api_http_500")
        self.assertEqual(self.escada.chamadas[JEV], 1)
        proximo = estado(900)
        proximo["objective"]["id"] = "pedro_outro"
        self.escada.observar(proximo, "", TAREFA)
        self.assertEqual(self.escada.chamadas[JEV], 0)

    def test_context_is_lean(self):
        contexto = contexto_enxuto(estado(5, interaction_target="Pedro"), ACOES, TAREFA,
                                   [{"action": f"a{i}", "result": "ok"} for i in range(30)], [], ["Precisa de Machado."], [], JEV)
        self.assertEqual(len(contexto["recent_actions"]), 10)
        self.assertNotIn("world_map", contexto)
        self.assertLess(len(json.dumps(contexto)), 4000)
        self.assertEqual(contexto["refusals"], ["Precisa de Machado."])

    def test_simulated_plan_follows_the_requirement_then_recovery(self):
        self.assertEqual(plano_simulado(TAREFA, ACOES), ["gather_pedra", "walk_left"])


class ProgressoTests(unittest.TestCase):
    CADEIAS = [
        {"name": "Chegada ao arraial", "main": True, "started": True, "completed": True, "step": 16, "total": 16},
        {"name": "O mirante", "main": True, "started": True, "completed": False, "step": 2, "total": 6},
        {"name": "Favor do vizinho", "main": False, "started": True, "completed": False, "step": 1, "total": 3},
        {"name": "O convite", "main": True, "started": False, "completed": False, "step": -1, "total": 4, "locked": True},
    ]

    def test_main_chains_make_the_chapters_and_side_chains_stay_out(self):
        itens = capitulos({"mission_chains": self.CADEIAS})
        self.assertEqual([c["nome"] for c in itens], ["Chegada ao arraial", "O mirante", "O convite"])

    def test_percentage_chapter_and_milestones(self):
        resultado = medir({"mission_chains": self.CADEIAS, "objective": {"titulo": "Subir ao mirante"}})
        self.assertEqual((resultado["feitos"], resultado["total"]), (18, 26))
        self.assertEqual(resultado["percentual"], 69.2)
        self.assertEqual((resultado["capitulo"], resultado["capitulo_feitos"], resultado["capitulo_total"]),
                         ("O mirante", 2, 6))
        self.assertEqual([m["atual"] for m in resultado["marcos"]], [False, True, False])
        self.assertEqual(resultado["proximo_objetivo"], "Subir ao mirante")

    def test_pace_estimate_and_farthest_point(self):
        ritmo = Ritmo()
        base = medir({"mission_chains": self.CADEIAS})
        ritmo.observar({**base, "feitos": 10}, 0)
        for _ in range(10):
            ritmo.contar_acao()
        passo = ritmo.observar({**base, "feitos": 12, "percentual": 46.2}, 40, JEV)
        self.assertEqual((passo["passos"], passo["acoes"], passo["destravou"]), (2, 10, JEV))
        estimativa = ritmo.estimativa({**base, "feitos": 12})
        self.assertEqual(estimativa["acoes_por_passo"], 5.0)
        self.assertEqual(estimativa["acoes_restantes"], 5 * (26 - 12))
        self.assertEqual(ritmo.mais_distante["feitos"], 12)
        self.assertEqual(ritmo.por_capitulo["O mirante"], {JEV: 2})

    def test_pace_is_unknown_before_the_first_step(self):
        self.assertIsNone(Ritmo().estimativa(medir({"mission_chains": self.CADEIAS}))["acoes_por_passo"])


class DetectarTests(unittest.TestCase):
    def test_keys_missing_disables_support_with_the_reason_and_never_leaks_the_value(self):
        resposta = detectar_apoios({}, sonda=lambda host: True)
        self.assertTrue(resposta["apoios"]["deterministic"]["disponivel"])
        self.assertEqual(resposta["apoios"]["jev"], {"disponivel": False, "motivo": "sem_chave_typesafe"})
        self.assertEqual(resposta["apoios"]["gpt"], {"disponivel": False, "motivo": "sem_chave_openai"})
        self.assertEqual(resposta["orcamento"], {"padrao": 0.1, "teto": 0.5})

    def test_key_present_checks_the_endpoint_and_returns_no_secret(self):
        config = {"TYPESAFE_API_KEY": "segredo-jev", "OPENAI_API_KEY": "segredo-gpt"}
        chamados = []
        resposta = detectar_apoios(config, sonda=lambda host: chamados.append(host) or host == "api.typesafe.ai")
        self.assertEqual(sorted(chamados), ["api.openai.com", "api.typesafe.ai"])
        self.assertTrue(resposta["apoios"]["jev"]["disponivel"])
        self.assertEqual(resposta["apoios"]["gpt"], {"disponivel": False, "motivo": "sem_rede"})
        texto = json.dumps(resposta)
        self.assertNotIn("segredo", texto)

    def test_last_session_summary_feeds_the_modal_on_reopen(self):
        with tempfile.TemporaryDirectory() as pasta:
            sessao = Path(pasta) / "20261008-120000-abc"
            sessao.mkdir()
            (sessao / "resumo.json").write_text(json.dumps({"stop": "user_stop", "progresso": {
                "acoes": 412, "progresso": {"percentual": 43.5, "feitos": 24, "total": 56, "capitulo": "O mirante",
                                            "capitulo_feitos": 2, "capitulo_total": 6},
                "mais_distante": {"feitos": 24}}}), encoding="utf-8")
            resumo = ultima_sessao(Path(pasta))
        self.assertEqual((resumo["percentual"], resumo["acoes"], resumo["parou"]), (43.5, 412, "user_stop"))
        self.assertIsNone(ultima_sessao(Path(pasta) / "nao-existe"))


class SessaoComApoiosTests(unittest.TestCase):
    """A ponte com a escada ligada: planos do Jev/GPT por respostas falsas, sempre sob o teto."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.relogio = Relogio()
        self.session = Session(Path(self.temp.name), {"TYPESAFE_API_KEY": "fake-jev", "OPENAI_API_KEY": "fake-gpt"},
                               seconds=0, budget="0.10")
        self.session.escada = Escada((JEV, GPT), relogio=self.relogio, registrar=self.session.log_escada)

        class Robo:
            reason = "regra local"
            recovery = False
            alternate = None
            attempts = __import__("collections").Counter()

            def choose(self, state, actions, task):
                return "wait"

            def start_alternate(self, goal=None, why=""):
                self.alternate = {"stage": "target", "goal": goal}
        self.session.robot = Robo()

    def jev_ok(self, escolhas=("gather_pedra", "work_E", "gather_pedra"), tokens=900):
        respostas = {f"step_{i + 1}": {"choice": c, "confidence": 0.8} for i, c in enumerate(escolhas)}
        return io.BytesIO(json.dumps({"model": "jev", "usage": {"input_tokens": tokens}, "answers": respostas}).encode())

    def gpt_ok(self, plano=("walk_left", "interact")):
        corpo = {"choices": [{"message": {"content": json.dumps({"plan": list(plano), "reason": "contornar o Pedro"})}}],
                 "usage": {"prompt_tokens": 1200, "completion_tokens": 40}}
        return io.BytesIO(json.dumps(corpo).encode())

    def empurrar(self, rodadas=60, inicio=0, **extra):
        decisoes = []
        for i in range(rodadas):
            estado_i = estado((inicio + i) * 2, posicao=((inicio + i) * 3.0, 0, 0), **extra)
            decisao = self.session.decide_robot(estado_i, dict(ACOES))
            decisoes.append(decisao)
            if decisao.get("level") in (JEV, GPT) or decisao.get("stop"):
                break
        return decisoes

    def test_deterministic_decision_carries_level_reason_and_progress_for_the_panel(self):
        decisao = self.session.decide_robot(estado(0, mission_chains=ProgressoTests.CADEIAS), dict(ACOES))
        self.assertEqual((decisao["level"], decisao["mode"], decisao["rationale"]), (DETERMINISTICO, "normal", "regra local"))
        self.assertEqual(decisao["progress"]["total"], 26)
        self.assertIn("pace", decisao["progress"])

    def test_jev_plan_is_charged_logged_and_executed(self):
        with patch("jogar.urlopen", side_effect=lambda *a, **k: self.jev_ok()) as pedido:
            decisoes = self.empurrar()
        self.assertEqual(pedido.call_count, 1)
        ultima = decisoes[-1]
        self.assertEqual((ultima["level"], ultima["choice"], ultima["mode"], ultima["plan"]), (JEV, "gather_pedra", "plan", [1, 3]))
        self.assertIn("Plano do Jev (1/3)", ultima["rationale"])
        self.assertEqual(ultima["escalations"], 1)
        self.assertGreater(self.session.cost, 0)
        eventos = [json.loads(l) for l in (Path(self.temp.name) / "eventos.jsonl").read_text(encoding="utf-8").splitlines()]
        escalonamento = next(e for e in eventos if e["kind"] == "escalation")
        self.assertEqual((escalonamento["nivel"], escalonamento["plano"][0]), (JEV, "gather_pedra"))
        self.assertTrue(escalonamento["sinais"])

    def test_request_goes_only_to_the_official_endpoint_with_a_lean_context(self):
        with patch("jogar.urlopen", side_effect=lambda *a, **k: self.jev_ok()) as pedido:
            self.empurrar()
        requisicao = pedido.call_args.args[0]
        self.assertEqual(requisicao.full_url, "https://api.typesafe.ai/v1/systemone")
        corpo = json.loads(requisicao.data)
        self.assertEqual(sorted(corpo["questions"]), ["step_1", "step_2", "step_3"])
        self.assertLess(len(requisicao.data), 20_000)
        self.assertNotIn("mission_definitions", requisicao.data.decode())

    def test_gpt_gets_the_failed_plan_and_is_priced_by_usage(self):
        respostas = [self.jev_ok(("walk_left", "walk_left", "walk_left")), self.gpt_ok()]
        with patch("jogar.urlopen", side_effect=lambda *a, **k: respostas.pop(0)) as pedido:
            self.empurrar()
            for i in range(3):
                self.session.decide_robot(estado(500 + i, posicao=(700 + i * 3.0, 0, 0)), dict(ACOES))
            self.relogio.agora += 60
            decisoes = self.empurrar(rodadas=3, inicio=300)
        self.assertEqual(pedido.call_count, 2)
        requisicao = pedido.call_args.args[0]
        self.assertEqual(requisicao.full_url, "https://api.openai.com/v1/chat/completions")
        mensagem = json.loads(json.loads(requisicao.data)["messages"][1]["content"])
        self.assertEqual(mensagem["context"]["failed_plans"][0]["plan"], ["walk_left", "walk_left", "walk_left"])
        self.assertEqual(decisoes[-1]["level"], GPT)
        self.assertEqual(self.session.custo_por_nivel[GPT] > 0, True)

    def test_budget_below_the_reservation_never_calls_and_keeps_playing(self):
        self.session.budget = Decimal("0")
        with patch("jogar.urlopen") as pedido:
            decisoes = self.empurrar(rodadas=80)
        pedido.assert_not_called()
        self.assertFalse(decisoes[-1].get("stop"))
        self.assertEqual(self.session.api_calls, 0)

    def test_api_error_never_leaks_the_key_and_counts_as_a_failure(self):
        erro = __import__("urllib.error").error.HTTPError("u", 401, "no", {}, io.BytesIO(b"bad fake-jev token"))
        with patch("jogar.urlopen", side_effect=erro):
            self.empurrar()
        registro = (Path(self.temp.name) / "eventos.jsonl").read_text(encoding="utf-8")
        self.assertNotIn("fake-jev", registro)
        self.assertIn("[redacted]", registro)

    def test_missing_key_denies_the_level_without_spending(self):
        self.session.config = {}
        with patch("jogar.urlopen") as pedido:
            self.empurrar(rodadas=80)
        pedido.assert_not_called()

    def test_simulated_ladder_runs_without_any_api_call(self):
        self.session.simulada = True
        with patch("jogar.urlopen") as pedido:
            decisoes = self.empurrar()
        pedido.assert_not_called()
        self.assertEqual(decisoes[-1]["level"], JEV)
        self.assertEqual(self.session.cost, 0)

    def ate_o_modal(self):
        """Roda a escada simulada até a ponte pedir o modal de bloqueio; devolve (decisão, i)."""
        self.session.simulada = True
        for i in range(400):
            self.relogio.agora += 60
            decisao = self.session.decide_robot(estado(i * 2, posicao=(i * 3.0, 0, 0)), dict(ACOES))
            self.assertFalse(decisao.get("stop"))
            if decisao.get("blocked"):
                return decisao, i
        self.fail("a escada nunca pediu o modal")

    def eventos(self):
        return [json.loads(l) for l in (Path(self.temp.name) / "eventos.jsonl").read_text(encoding="utf-8").splitlines()]

    def test_block_opens_the_modal_once_and_waits_for_the_choice(self):
        decisao, i = self.ate_o_modal()
        self.assertEqual(decisao["blocked"]["step"], "pedro_pedra")
        self.assertTrue(decisao["blocked"]["reason"])
        self.assertTrue(decisao["blocked"]["tries"])
        self.assertEqual(decisao["choice"], "wait")
        self.assertTrue(decisao["capture"])
        # Sem resposta ainda: espera, sem repetir o pedido do modal.
        seguinte = self.session.decide_robot(estado(i * 2 + 2), dict(ACOES))
        self.assertEqual((seguinte["choice"], seguinte["mode"]), ("wait", "blocked"))
        self.assertNotIn("blocked", seguinte)

    def test_block_stops_the_session_with_the_context_logged(self):
        decisao, i = self.ate_o_modal()
        decisao = self.session.decide_robot(estado(i * 2 + 2, blocked_choice="stop"), dict(ACOES))
        self.assertEqual(decisao["stop"], "blocked_step")
        self.assertTrue(decisao["capture"])
        bloqueio = next(e for e in self.eventos() if e["kind"] == "blocked_step")
        self.assertEqual(bloqueio["passo"], "pedro_pedra")
        self.assertIn("posicao", bloqueio)

    def test_block_alternate_or_timeout_never_ends_the_session(self):
        for escolha in ("timeout", "alternate"):
            with self.subTest(escolha=escolha):
                self.setUp()
                decisao, i = self.ate_o_modal()
                pedidos = 1
                decisao = self.session.decide_robot(estado(i * 2 + 2, blocked_choice=escolha), dict(ACOES))
                self.assertEqual(decisao["mode"], "alternate")
                for j in range(300):
                    self.relogio.agora += 60
                    decisao = self.session.decide_robot(estado(1000 + j * 2, posicao=(j * 3.0, 0, 0)), dict(ACOES))
                    self.assertFalse(decisao.get("stop"))
                    pedidos += bool(decisao.get("blocked"))
                self.assertEqual(pedidos, 1)
                tipos = [e["kind"] for e in self.eventos()]
                self.assertIn("blocked_choice", tipos)
                self.assertIn("alternate_route", tipos)
                self.assertNotIn("blocked_step", tipos)

    def test_block_takeover_waits_for_the_human_and_resets_the_counters_on_return(self):
        decisao, i = self.ate_o_modal()
        decisao = self.session.decide_robot(estado(i * 2 + 2, blocked_choice="takeover"), dict(ACOES))
        self.assertFalse(decisao.get("stop"))
        self.assertEqual(self.session.escada.fase, "normal")
        self.session.manual_control({"phase": "end", "after": {"seconds": 5000}})
        self.assertEqual(self.session.escada.detector.acoes, 0)
        self.assertIn("ladder_resumed", [e["kind"] for e in self.eventos()])

    def test_jev_plan_made_only_of_failed_actions_is_rejected_and_asked_again_harder(self):
        self.session.results = [{"action": "walk_left", "result": "movement_blocked_no_displacement_try_other_direction"}] * 2
        respostas = [self.jev_ok(("walk_left", "walk_left", "walk_left")), self.jev_ok()]
        with patch("jogar.urlopen", side_effect=lambda *a, **k: respostas.pop(0)) as pedido:
            decisoes = self.empurrar()
        self.assertEqual(pedido.call_count, 2)
        primeiro = json.loads(pedido.call_args_list[0].args[0].data)
        self.assertEqual(json.loads(primeiro["state"])["failed_actions"], {"walk_left": 2})
        self.assertIn("Do NOT repeat", primeiro["questions"]["step_1"]["instructions"])
        segundo = json.loads(pedido.call_args_list[1].args[0].data)
        self.assertNotIn("walk_left", segundo["questions"]["step_1"]["criteria"])
        self.assertIn("REJECTED", segundo["questions"]["step_1"]["instructions"])
        self.assertEqual((decisoes[-1]["level"], decisoes[-1]["choice"]), (JEV, "gather_pedra"))
        self.assertIn("plan_rejected", [e["kind"] for e in self.eventos()])

    def test_gpt_invalid_answer_is_logged_and_retried_once(self):
        self.session.escada = Escada((GPT,), relogio=self.relogio, registrar=self.session.log_escada)
        vazio = {"choices": [{"message": {"content": ""}, "finish_reason": "length"}],
                 "usage": {"prompt_tokens": 1200, "completion_tokens": 4000}}
        respostas = [io.BytesIO(json.dumps(vazio).encode()), self.gpt_ok()]
        with patch("jogar.urlopen", side_effect=lambda *a, **k: respostas.pop(0)) as pedido:
            decisoes = self.empurrar()
        self.assertEqual(pedido.call_count, 2)
        corpo = json.loads(pedido.call_args.args[0].data)
        self.assertEqual((corpo["model"], corpo["reasoning_effort"], corpo["max_completion_tokens"]),
                         (GPT_MODELO_PADRAO, "low", 4000))
        self.assertEqual(GPT_MODELO_PADRAO, "gpt-5.6-luna")
        self.assertEqual(decisoes[-1]["level"], GPT)
        invalida = next(e for e in self.eventos() if e["kind"] == "gpt_invalid_answer")
        self.assertEqual((invalida["finish_reason"], invalida["empty"]), ("length", True))
        self.assertNotIn("fake-gpt", (Path(self.temp.name) / "eventos.jsonl").read_text(encoding="utf-8"))

    def test_resume_pointer_is_written_and_read_back_for_the_modal(self):
        pasta = Path(self.temp.name) / "jev"
        perfil = Path(self.temp.name) / "perfil"
        perfil.mkdir()
        self.session.ponteiro = pasta / "ultima_sessao.json"
        self.session.perfil = perfil
        self.session.decide_robot(estado(0, mission_chains=ProgressoTests.CADEIAS), dict(ACOES))
        self.session.gravar_ponteiro()
        ponteiro = ler_ponteiro(self.session.ponteiro)
        self.assertEqual(ponteiro["perfil"], str(perfil))
        self.assertEqual(ponteiro["resumo"]["passo"], "pedro_pedra")
        self.assertEqual(sorted(ponteiro["resumo"]), ["acoes", "capitulo", "custo", "passo", "pct", "quando"])
        resumo = ultima_sessao(pasta)
        self.assertTrue(resumo["continuar"]["disponivel"])
        self.assertEqual(resumo["continuar"]["passo"], "pedro_pedra")
        self.assertIsNone(ler_ponteiro(pasta / "nao-existe.json"))

    def test_resolved_stuck_writes_the_learned_pattern_file(self):
        self.session.simulada = True
        decisoes = self.empurrar()
        self.assertEqual(decisoes[-1]["level"], JEV)
        self.session.decide_robot(estado(900, feito=2, posicao=(1, 0, 0)), dict(ACOES))
        arquivo = Path(self.temp.name) / "aprendizado.json"
        self.assertTrue(arquivo.exists())
        self.assertEqual(json.loads(arquivo.read_text(encoding="utf-8"))[0]["nivel"], JEV)

    def test_summary_has_progress_curve_farthest_point_and_cost_by_level(self):
        cadeias = json.loads(json.dumps(ProgressoTests.CADEIAS))
        self.session.decide_robot(estado(0, mission_chains=cadeias), dict(ACOES))
        cadeias[1]["step"] = 3
        self.session.decide_robot(estado(10, mission_chains=cadeias, posicao=(9, 0, 0)), dict(ACOES))
        self.session.results.append({"action": "wait", "result": "ok", "after": estado(20, mission_chains=cadeias)})
        resumo = self.session.resumo_da_escada()
        self.assertEqual(resumo["progresso"]["mais_distante"]["feitos"], 19)
        self.assertEqual(len(resumo["progresso"]["curva"]), 1)
        self.assertIn("cost_by_level_usd", resumo)

    def test_report_lists_escalations_block_progress_and_pace(self):
        from relatorio import generate
        self.session.simulada = True
        cadeias = json.loads(json.dumps(ProgressoTests.CADEIAS))
        for i in range(400):
            self.relogio.agora += 60
            if i == 3:
                cadeias[1]["step"] = 3
            decisao = self.session.decide_robot(estado(i * 2, posicao=(i * 3.0, 0, 0), mission_chains=cadeias), dict(ACOES))
            if decisao.get("blocked"):
                self.session.decide_robot(estado(i * 2 + 1, blocked_choice="stop"), dict(ACOES))
                break
        for nome in ("stdout.log", "stderr.log"):
            (Path(self.temp.name) / nome).write_text("", encoding="utf-8")
        self.session.results.append({"action": "wait", "result": "ok", "before": {}, "after": estado(30, mission_chains=cadeias)})
        self.session.report(0)
        texto = (Path(self.temp.name) / "relatorio.md").read_text(encoding="utf-8")
        self.assertIn("## Escada de decisão", texto)
        self.assertIn("| Jev |", texto)
        self.assertIn("### Bloqueio", texto)
        self.assertIn("esgotou os apoios", texto)
        self.assertIn("## Progresso até zerar o jogo", texto)
        self.assertIn("Ponto mais distante", texto)
        self.assertIn("Capítulo", texto)


if __name__ == "__main__":
    unittest.main()
