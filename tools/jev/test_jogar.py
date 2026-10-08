"""Verify spending boundaries with fake API responses: never requires a key."""
import io
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from jogar import MAX_BODY, MAX_TOKENS, PRICE, ProgressGuard, Session, game_reference, current_task


# Nomes próprios e palavras que são a mesma nas três línguas: a cópia é a tradução certa.
IGUAIS_NO_IDIOMA = {"nivel_jev_en", "nivel_jev_es", "nivel_gpt_en", "nivel_gpt_es", "capitulo_es",
                    "parar_curto_es", "a_wait_es", "a_dodge_es", "a_run_es", "a_explore_es"}


class SpendingTests(unittest.TestCase):
    def test_work_materials_follow_observed_discount_without_mutating_game_step(self):
        step = {"id": "mirante_material", "meta": {"tipo": "juntar", "da_obra": "mirante_levantar"}}
        state = {"objective": {"id": "pedro_mirante_material"},
                 "mission_chains": [{"started": True, "main": True, "current_step": step}],
                 "work_costs": {"mirante_levantar": {"tabua": 18, "pedra": 11, "corda": 6}}}
        task = current_task(state, {})
        self.assertEqual(task["step"]["meta"].get("itens"), {"tabua": 18, "pedra": 11, "corda": 6})
        self.assertNotIn("itens", step["meta"])
        task["step"]["meta"]["itens"]["tabua"] = 999
        self.assertEqual(state["work_costs"]["mirante_levantar"]["tabua"], 18)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.session = Session(Path(self.temp.name), {"TYPESAFE_API_KEY": "fake-key"})

    def response(self, choice="walk", tokens=800):
        return io.BytesIO(json.dumps({"model": "fake", "usage": {"input_tokens": tokens},
                                      "answers": {"action": {"choice": choice, "confidence": 0.9}}}).encode())

    def test_insufficient_reservation_never_calls_api(self):
        self.session.cost = self.session.budget - PRICE * MAX_TOKENS / 2
        with patch("jogar.urlopen") as request:
            self.assertEqual(self.session.decide({}, {"walk": "walk"})["stop"], "budget")
            request.assert_not_called()

    def test_actual_usage_releases_reservation(self):
        with patch("jogar.urlopen", return_value=self.response()):
            self.assertEqual(self.session.decide({}, {"walk": "walk"})["choice"], "walk")
        self.assertEqual(self.session.cost, PRICE * 800)

    def test_timeout_retains_reservation_and_stops_retries(self):
        with patch("jogar.urlopen", side_effect=TimeoutError) as request:
            self.session.decide({}, {"walk": "walk"})
            self.session.decide({}, {"walk": "walk"})
            self.assertEqual(request.call_count, 1)
        self.assertEqual(self.session.cost, PRICE * MAX_TOKENS)

    def test_context_error_retries_once_with_reserved_cost(self):
        error = HTTPError("https://api.typesafe.ai/v1/systemone", 400, "Bad request", {},
                          io.BytesIO(b'{"detail":{"error_type":"max_tokens_exceeded"}}'))
        with patch("jogar.urlopen", side_effect=[error, self.response()]) as request, patch("jogar.time.sleep"):
            self.assertEqual(self.session.decide({"position": [0, 0, 0]}, {"walk": "walk"})["choice"], "walk")
            retry = json.loads(json.loads(request.call_args.args[0].data)["state"])
        self.assertNotIn("mission_definitions", retry["game_reference"])
        self.assertIn("current_task", retry)
        self.assertEqual(self.session.calls, 2)
        self.assertEqual(self.session.cost, PRICE * (MAX_TOKENS + 800))

    def test_context_retry_cannot_exceed_budget(self):
        self.session.budget = PRICE * MAX_TOKENS
        error = HTTPError("https://api.typesafe.ai/v1/systemone", 400, "Bad request", {},
                          io.BytesIO(b'{"error_type":"max_tokens_exceeded"}'))
        with patch("jogar.urlopen", side_effect=error) as request:
            self.assertEqual(self.session.decide({}, {"walk": "walk"})["stop"], "budget")
        self.assertEqual(request.call_count, 1)

    def test_duration_and_calls_stop_before_api(self):
        self.session.game_started = time.monotonic() - 601
        with patch("jogar.urlopen") as request:
            self.assertEqual(self.session.decide({}, {"walk": "walk"})["stop"], "duration")
            request.assert_not_called()
        self.session.stop_reason = ""
        self.session.game_started = None
        self.session.calls = 300
        with patch("jogar.urlopen") as request:
            self.assertEqual(self.session.decide({}, {"walk": "walk"})["stop"], "call_limit")
            request.assert_not_called()

    def test_invalid_choice_is_never_executed(self):
        with patch("jogar.urlopen", return_value=self.response(choice="delete_save")):
            result = self.session.decide({}, {"walk": "walk"})
        self.assertEqual(result["stop"], "invalid_api_answer")
        self.assertNotIn("choice", result)
        self.assertEqual(self.session.cost, PRICE * MAX_TOKENS)

    def test_budget_mode_has_no_time_or_call_limit(self):
        self.session.seconds = 0
        self.session.max_calls = 0
        self.session.game_started = time.monotonic() - 10000
        self.session.calls = 301
        with patch("jogar.urlopen", return_value=self.response()):
            self.assertEqual(self.session.decide({}, {"walk": "walk"})["choice"], "walk")
        self.assertIsNone(self.session.status()["remaining_seconds"])
        self.session.cost = self.session.budget
        with patch("jogar.urlopen") as request:
            self.assertEqual(self.session.decide({}, {"walk": "walk"})["stop"], "budget")
            request.assert_not_called()

    def test_campaign_mode_keeps_recovery_hint_without_idle_stop(self):
        self.session.progress = ProgressGuard(0)
        state = {"seconds": 0, "position": [0, 0, 0]}
        self.session.progress.observe(state)
        state["seconds"] = 300
        with patch("jogar.urlopen", return_value=self.response()) as request:
            self.assertEqual(self.session.decide(state, {"walk": "walk"})["choice"], "walk")
            sent = json.loads(request.call_args.args[0].data)
            sent["state"] = json.loads(sent["state"])
        self.assertTrue(sent["state"]["progress_watch"]["recovery_needed"])
        self.assertIsNone(sent["state"]["progress_watch"]["stop_after_seconds"])

    def test_oversized_state_never_calls_api(self):
        with patch("jogar.urlopen") as request:
            result = self.session.decide({"text": "a" * MAX_BODY}, {"walk": "walk"})
            self.assertEqual(result["stop"], "state_too_large")
            request.assert_not_called()

    def test_offline_never_calls_api(self):
        self.session.offline = True
        with patch("jogar.urlopen") as request:
            result = self.session.decide({}, {"walk": "walk"})
            request.assert_not_called()
        self.assertEqual(result["estimated_usd"], 0)

    def test_request_includes_campaign_knowledge_and_live_requirements(self):
        state = {"position": [0, 0, 0], "mission_chains": [{"current_step": {"meta": {"tipo": "falar", "a_quem": "zefa"}}}],
                 "inventory": {"in_hand": "enxada"}, "pedro": {"waiting_for_player": True}}
        with patch("jogar.urlopen", return_value=self.response()) as request:
            self.session.decide(state, {"walk": "walk"})
        payload = json.loads(request.call_args.args[0].data)
        payload["state"] = json.loads(payload["state"])
        context = payload["state"]
        self.assertEqual(context["mission_chains"], state["mission_chains"])
        self.assertEqual(context["inventory"], state["inventory"])
        files = {x["file"] for x in context["game_reference"]["mission_definitions"]}
        self.assertIn("missoes_fazenda.json", files)
        self.assertIn("missoes_ponte.json", files)
        self.assertIn("FINISH", payload["questions"]["action"]["instructions"])
        self.assertLess(len(request.call_args.args[0].data), MAX_BODY)

    def test_campaign_options_above_old_40_limit_are_available(self):
        actions = {"walk": "walk", **{f"npc_{i}": f"Visit NPC {i}" for i in range(100)}}
        with patch("jogar.urlopen", return_value=self.response()):
            self.assertEqual(self.session.decide({}, actions)["choice"], "walk")

    def test_guide_mock_continues_following_instead_of_repeating_E(self):
        state = {"pedro": {"conducting": True, "guide_destination_reached": False}, "interaction_target": "Pedro"}
        self.assertEqual(Session.mock_choice(state, {"interact": "E", "follow_pedro": "follow"}), "follow_pedro")

    def test_story_endpoint_stops_without_another_paid_call(self):
        with patch("jogar.urlopen") as request:
            result = self.session.decide({"implemented_story_completed": True}, {"walk": "walk"})
        request.assert_not_called()
        self.assertEqual(result["stop"], "implemented_story_completed")

    def test_partial_objective_progress_keeps_working(self):
        guard = ProgressGuard()
        state = {"seconds": 0, "position": [0, 0, 0], "objective": {"id": "wood", "feito": 0, "total": 3}}
        self.assertFalse(guard.observe(state))
        state["seconds"] = 25
        state["objective"]["feito"] = 1
        self.assertFalse(guard.observe(state))
        state["seconds"] = 40
        self.assertFalse(guard.observe(state))
        state["seconds"] = 55
        self.assertTrue(guard.observe(state))

    def test_near_required_npc_is_exposed_even_when_guide_has_not_arrived(self):
        state = {"objective": {"id": "pedro_chave"}, "pedro": {"conducting": True, "guide_destination_reached": False},
                 "mission_chains": [{"started": True, "main": True, "current_step": {"id": "chave", "meta": {"tipo": "falar", "a_quem": "candinha"}}}],
                 "npcs": [{"id": "candinha", "node": "MoradorCandinha", "name": "Dona Candinha", "distance": 7.7}]}
        task = current_task(state, {"follow_pedro": "follow", "approach_MoradorCandinha": "approach"})
        self.assertEqual(task["actions_matching_the_current_requirement"], ["approach_MoradorCandinha"])
        state["interaction_target"] = "MoradorCandinha"
        self.assertEqual(current_task(state, {"interact": "E", "follow_pedro": "follow"})["actions_matching_the_current_requirement"], ["interact"])

    def test_run_requirement_is_distinguished_from_future_NPC_missions(self):
        state = {"objective": {"id": "pedro_correr"}, "mission_chains": [{"started": True, "main": True,
                 "current_step": {"id": "correr", "meta": {"tipo": "evento", "evento": "correu"}}}]}
        task = current_task(state, {"run_backward": "run", "approach_MoradorTonho": "approach"})
        self.assertEqual(task["actions_matching_the_current_requirement"], ["run_backward"])

    def test_failed_guide_action_exposes_recovery_without_hiding_options(self):
        state = {"objective": {"id": "pedro_chave_zefa"}, "pedro": {"conducting": True},
                 "mission_chains": [{"started": True, "main": True, "current_step": {"id": "chave_zefa", "meta": {"tipo": "falar", "a_quem": "zefa"}}}],
                 "npcs": [{"id": "zefa", "name": "Dona Zefa", "node": "MoradorZefa", "distance": 201}],
                 "recent_actions": [{"action": "follow_pedro", "result": "possible_stuck_requires_review"}]}
        actions = {"follow_pedro": "follow", "walk_left": "left", "approach_MoradorZefa": "approach"}
        task = current_task(state, actions)
        self.assertEqual(task["actions_matching_the_current_requirement"], [])
        self.assertEqual(task["last_action_failed"], ["follow_pedro"])
        self.assertEqual(task["recovery_options"], ["walk_left"])
        self.assertIn("follow_pedro", actions)

    def test_run_endpoints_are_part_of_the_current_task_information(self):
        state = {"objective": {"id": "pedro_correr"}, "mission_chains": [{"started": True, "main": True,
                 "current_step": {"id": "correr", "meta": {"evento": "correu"}}}],
                 "directions": {"backward": {"run_endpoint_walkable": False}, "left": {"run_endpoint_walkable": True}}}
        actions = {"run_backward": "run backward", "run_left": "run left"}
        self.assertEqual(current_task(state, actions)["actions_matching_the_current_requirement"], ["run_left"])
        self.assertIn("run_backward", actions)

    def test_worst_case_calls_cannot_exceed_budget(self):
        with patch("builtins.print"):
            while not self.session.stop_reason:
                with patch("jogar.urlopen", return_value=self.response(tokens=MAX_TOKENS)):
                    self.session.decide({}, {"walk": "walk"})
        self.assertEqual(self.session.stop_reason, "budget")
        self.assertLessEqual(self.session.cost, self.session.budget)
        self.assertEqual(self.session.calls, 37)

    def test_panel_translations_preserve_format_fields(self):
        texts = json.loads((Path(__file__).parent / "textos.json").read_text(encoding="utf-8"))
        import re
        for key in [name for name in texts if not name.endswith(("_en", "_es"))]:
            placeholders = re.findall(r"%[.\d]*[sdf]", texts[key])
            for suffix in ("_en", "_es"):
                self.assertTrue(texts[key + suffix])
                if (key + suffix) not in IGUAIS_NO_IDIOMA:
                    self.assertNotEqual(texts[key], texts[key + suffix])
                self.assertEqual(placeholders, re.findall(r"%[.\d]*[sdf]", texts[key + suffix]))

    def test_repeating_a_loop_stops_after_30_seconds(self):
        guard = ProgressGuard()
        for second in range(31):
            state = {"seconds": second, "position": [85 + second % 2, 0, -3],
                     "objective": {"id": "greet_tonho"}}
            self.assertEqual(guard.observe(state), second == 30)

    def test_progress_keeps_playing_but_revisited_cells_do_not(self):
        guard = ProgressGuard()
        self.assertFalse(guard.observe({"seconds": 0, "position": [0, 0, 0]}))
        self.assertFalse(guard.observe({"seconds": 25, "position": [10, 0, 0]}))
        self.assertFalse(guard.observe({"seconds": 45, "position": [0, 0, 0]}))
        self.assertTrue(guard.observe({"seconds": 55, "position": [10, 0, 0]}))

    def test_same_dialogue_does_not_reset_idle_guard(self):
        guard = ProgressGuard()
        state = {"seconds": 0, "position": [0, 0, 0],
                 "dialogue": {"active": True, "speaker": "Pedro", "text": "Go greet Tonho"}}
        self.assertFalse(guard.observe(state))
        state["seconds"] = 30
        self.assertTrue(guard.observe(state))

    def test_no_progress_blocks_the_next_paid_request(self):
        state = {"seconds": 0, "position": [85, 0, -3], "objective": {"id": "greet_tonho"}}
        self.session.progress.observe(state)
        state["seconds"] = 30
        with patch("jogar.urlopen") as request:
            self.assertEqual(self.session.decide(state, {"walk": "walk"})["stop"], "no_progress_30s")
            request.assert_not_called()


if __name__ == "__main__":
    unittest.main()
