"""Focused behavioral checks for deterministic exploration and evidence reports."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from robo import JogadorAutomatico
from relatorio import generate


class PlayerTests(unittest.TestCase):
    def player(self):
        bot = JogadorAutomatico()
        bot.action_delay = bot.work_delay = 0
        return bot

    def state(self):
        return {"seconds": 0, "position": [0, 0, 0], "objective": {"id": "stone", "feito": 0},
                "inventory": {"in_hand": "balde", "slots": [{"id": "balde", "qtd": 1}, {"id": "picareta", "qtd": 1}]}}

    def test_resource_equips_required_tool_before_moving(self):
        bot = self.player()
        self.assertEqual(bot.choose(self.state(), {"objective": "move", "hand_1": "equip"},
                                    {"step": {"meta": {"tipo": "juntar", "item": "pedra", "quantos": 3}}}), "hand_1")

    def test_clock_and_walking_do_not_count_as_mission_progress(self):
        bot = self.player()
        state = self.state()
        actions = {"objective": "move", "observe": "look", "inspect_journal": "read", "wait": "wait"}
        bot.choose(state, actions, {})
        state.update(seconds=31, position=[1, 0, 0], clock={"time": "later"})
        choice = bot.choose(state, actions, {})
        self.assertTrue(bot.recovery)
        self.assertEqual(choice, "observe")
        choice = bot.choose(state, actions, {})
        self.assertEqual(choice, "inspect_journal")

    def test_progress_exits_recovery(self):
        bot = self.player()
        state = self.state()
        actions = {"wait": "wait"}
        bot.choose(state, actions, {})
        state["seconds"] = 31
        bot.choose(state, actions, {})
        self.assertTrue(bot.recovery)
        state["objective"]["feito"] = 1
        bot.choose(state, actions, {})
        self.assertFalse(bot.recovery)

    def test_recipe_uses_observed_order_not_hardcoded_slot(self):
        bot = self.player()
        state = self.state()
        state.update(screen="panel", panel={"tab": 3, "cursor": 0},
                     crafting={"Oficina": [{"id": "tabua"}, {"id": "corda", "impediment": ""}]})
        task = {"step": {"meta": {"tipo": "juntar", "item": "corda", "quantos": 1}}}
        actions = {"screen_down": "down", "confirm_screen": "confirm"}
        self.assertEqual(bot.choose(state, actions, task), "screen_down")
        state["panel"]["cursor"] = 1
        self.assertEqual(bot.choose(state, actions, task), "confirm_screen")

    def test_same_observations_produce_same_choices(self):
        bots = [self.player(), self.player()]
        actions = {"observe": "look", "inspect_journal": "read", "wait": "wait"}
        traces = []
        for bot in bots:
            state = self.state()
            traces.append([bot.choose(dict(state, seconds=i * 31), actions, {}) for i in range(5)])
        self.assertEqual(*traces)

    def test_disabled_controls_never_choose_unavailable_inspection(self):
        bot = self.player()
        state = self.state()
        state.update(world_map={"Oficina": [0, 0, 0]}, crafting={"Oficina": [{"id": "corda"}]})
        task = {"step": {"meta": {"tipo": "juntar", "item": "corda", "quantos": 1}}}
        self.assertEqual(bot.choose(state, {"wait": "disabled"}, task), "wait")


    def test_unavailable_contextual_action_does_not_stop_robot(self):
        bot = self.player()
        task = {"step": {"meta": {"eventos": ["abriu_painel"]}}}
        self.assertEqual(bot.choose(self.state(), {"wait": "wait", "observe": "look"}, task), "observe")

    def test_stale_direct_requirement_is_filtered_by_allowlist(self):
        bot = self.player()
        task = {"actions_matching_the_current_requirement": ["removed", "interact"]}
        self.assertEqual(bot.choose(self.state(), {"interact": "E", "wait": "wait"}, task), "interact")

    def test_progress_renews_contextual_attempts(self):
        bot = self.player()
        state = self.state()
        state["interaction_target"] = "Lavoura"
        actions = {"interact": "E", "wait": "wait", "observe": "look"}
        task = {"actions_matching_the_current_requirement": ["interact"]}
        bot.choose(state, actions, task)
        bot.choose(state, actions, task)
        bot.choose(state, actions, task)
        state["objective"]["feito"] = 1
        self.assertEqual(bot.choose(state, actions, task), "interact")
        self.assertFalse(bot.recovery)

    def test_failed_escape_does_not_repeat_same_collision(self):
        bot = self.player()
        actions = {"walk_forward": "move", "walk_left": "move", "wait": "wait"}
        task = {"last_action_failed": ["walk_forward"]}
        self.assertEqual(bot.choose(self.state(), actions, task), "walk_left")

    def test_long_guided_walk_keeps_current_requirement_before_exploring(self):
        bot = self.player()
        state = self.state()
        actions = {"follow_pedro": "follow", "observe": "look", "wait": "wait"}
        task = {"actions_matching_the_current_requirement": ["follow_pedro"]}
        bot.choose(state, actions, task)
        state.update(seconds=31, position=[10, 0, 0])
        self.assertEqual(bot.choose(state, actions, task), "follow_pedro")

    def test_nearby_chest_does_not_press_E_on_another_npc(self):
        bot = self.player()
        state = self.state()
        state.update(interior="casa", home_interaction="bau", interaction_target="Pedro")
        task = {"step": {"meta": {"tipo": "juntar", "itens": {"enxada": 1}}}}
        self.assertEqual(bot.choose(state, {"interact": "Pedro", "face_CasaDoJogador": "chest", "wait": "wait"}, task), "face_CasaDoJogador")

    def test_waits_for_active_speech_instead_of_repeated_approach(self):
        bot = self.player()
        task = {"required_npc": {"speaking": True, "distance": 2}, "actions_matching_the_current_requirement": ["follow_pedro"]}
        self.assertEqual(bot.choose(self.state(), {"wait": "wait", "follow_pedro": "follow"}, task), "wait")

    def test_resource_candidate_has_priority_over_pedro_during_recovery(self):
        bot = self.player()
        state = self.state()
        actions = {"interact": "Pedro", "face_Recursos3D": "turn", "observe": "look", "wait": "wait"}
        task = {"step": {"meta": {"tipo": "juntar", "item": "lenha", "quantos": 3}}}
        bot.choose(state, actions, task)
        state.update(seconds=31, interaction_target="Pedro", interaction_candidates=[{"source": "Recursos3D", "target": {"ponto": [1, 0, 1]}}])
        state["objective"]["alvo"] = [1, 0, 1]
        self.assertEqual(bot.choose(state, actions, task), "face_Recursos3D")

    def test_unavailable_requirement_fallback_is_bounded_by_coverage(self):
        bot = self.player()
        task = {"step": {"meta": {"eventos": ["abriu_painel"]}}}
        state = self.state()
        actions = {"wait": "wait", "observe": "look"}
        self.assertEqual(bot.choose(state, actions, task), "observe")
        self.assertEqual(bot.choose(state, actions, task), "wait")

    def test_hidden_objective_during_speech_is_not_progress(self):
        bot = self.player()
        state = self.state()
        bot.choose(state, {"wait": "wait"}, {})
        bot.choose(dict(state, seconds=31, objective={}), {"wait": "wait"}, {})
        self.assertTrue(bot.recovery)


class ReportTests(unittest.TestCase):
    def test_report_distinguishes_key_execution_from_progress(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            before = {"position": [0, 0, 0], "objective": {"id": "a", "feito": 0}}
            after = {"position": [3, 0, 4], "objective": {"id": "a", "feito": 0}}
            records = [{"kind": "game_ready", "elapsed": 1},
                       {"kind": "decision", "elapsed": 2, "choice": "walk_forward", "rationale": "test", "latency_ms": 1400},
                       {"kind": "outcome", "elapsed": 4, "action": "walk_forward", "result": "moved", "before": before, "after": after, "movement_samples": [before, {"position": [3, 0, 0]}, after]}]
            (directory / "eventos.jsonl").write_text("\n".join(json.dumps(r) for r in records) + "\n{", encoding="utf-8")
            report = generate(directory).read_text(encoding="utf-8")
            self.assertIn("5.00 unidades", report)
            self.assertIn("7.00 unidades", report)
            self.assertIn("1.40 s", report)
            self.assertIn("sem avanço de missão", report)
            self.assertIn("não demonstrado", report)
            self.assertIn("2.00", report)

    def test_dialogue_hiding_objective_does_not_report_a_completed_step(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            state = {"objective": {"id": "same", "feito": 0}}
            hidden = {"objective": {}}
            records = [{"kind": "outcome", "elapsed": 1, "action": "interact", "before": state, "after": hidden},
                       {"kind": "outcome", "elapsed": 2, "action": "wait", "before": hidden, "after": state}]
            (directory / "eventos.jsonl").write_text("\n".join(json.dumps(r) for r in records), encoding="utf-8")
            report = generate(directory).read_text(encoding="utf-8")
            self.assertNotIn("miss\u00e3o avan\u00e7ou", report)


if __name__ == "__main__":
    unittest.main()
