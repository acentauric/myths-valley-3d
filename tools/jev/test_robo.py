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


class ReportTests(unittest.TestCase):
    def test_report_distinguishes_key_execution_from_progress(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            before = {"position": [0, 0, 0], "objective": {"id": "a", "feito": 0}}
            after = {"position": [3, 0, 4], "objective": {"id": "a", "feito": 0}}
            records = [{"kind": "game_ready", "elapsed": 1},
                       {"kind": "decision", "elapsed": 2, "choice": "walk_forward", "rationale": "test"},
                       {"kind": "outcome", "elapsed": 4, "action": "walk_forward", "result": "moved", "before": before, "after": after}]
            (directory / "eventos.jsonl").write_text("\n".join(json.dumps(r) for r in records) + "\n{", encoding="utf-8")
            report = generate(directory).read_text(encoding="utf-8")
            self.assertIn("5.00 unidades", report)
            self.assertIn("sem avanço de missão", report)
            self.assertIn("não demonstrado", report)
            self.assertIn("2.00", report)


if __name__ == "__main__":
    unittest.main()
