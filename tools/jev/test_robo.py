"""Focused behavioral checks for deterministic exploration and evidence reports."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from robo import JogadorAutomatico
from relatorio import generate


class PlayerTests(unittest.TestCase):
    def test_clock_controls_are_never_offered_or_chosen(self):
        # O relógio é do jogador (#192): nem a tecla de adiantar a hora, nem botão de tempo.
        bot, state = self.player(), self.state()
        actions = {"inspect_time": "Press T", "button_2": "Click Relógio", "button_3": "Click Velocidade",
                   "clock_toggle": "Click clock", "wait": "wait"}
        for attempt in range(12):
            choice = bot.choose(dict(state, seconds=attempt * 31), actions, {})
            self.assertEqual(choice, "wait")
        self.assertIsNone(bot.choose(state, {"inspect_time": "Press T"}, {}))

    def test_exploration_never_probes_the_time_controls(self):
        bot, state = self.player(), self.state()
        actions = {"observe": "F", "inspect_journal": "J", "inspect_map": "M", "inspect_time": "T", "wait": "wait"}
        seen = set()
        for attempt in range(40):
            seen.add(bot.choose(dict(state, seconds=attempt * 31, position=[attempt * 40, 0, 0]), actions, {}))
        self.assertNotIn("inspect_time", seen)

    def awake_with_finished_tutorial(self):
        """Acordou na casa herdada com o tutorial concluído: o Pedro já não conduz (#191)."""
        state = self.state()
        state.update(interior="casa", objective={}, journal={"ativas": []}, pedro={"conducting": False, "tutorial_finished": True},
                     mission_chains=[{"key": "pedro", "name": "mirante", "main": True, "started": False, "completed": False, "locked": False}],
                     room={"name": "casa", "outside_targets": ["approach_MoradorPedro", "objective", "explore_Praia"]})
        return state

    def test_finished_tutorial_inside_house_leaves_by_the_door_then_walks_to_the_guide_post(self):
        bot, state = self.player(), self.awake_with_finished_tutorial()
        actions = {"exit_home": "door", "approach_MoradorPedro": "post", "approach_bed": "bed", "wait": "wait"}
        self.assertEqual(bot.choose(state, actions, {}), "exit_home")
        state.update(interior="", room={})
        self.assertEqual(bot.choose(dict(state, position=[12, 0, 6]), actions, {}), "approach_MoradorPedro")

    def test_inside_any_room_a_target_outside_is_reached_through_the_door(self):
        # A igreja e o casarão saem pela mesma regra da casa (#191).
        for room, exit_action in (("igreja", "exit_room"), ("casarao", "exit_room"), ("casa", "exit_home")):
            bot, state = self.player(), self.state()
            state.update(interior=room, objective={"id": "x", "alvo": [30, 0, 30]}, room={"name": room, "outside_targets": ["objective", "follow_pedro", "explore_Praia"]})
            actions = {exit_action: "door", "objective": "go", "wait": "wait"}
            self.assertEqual(bot.choose(dict(state), actions, {"step": {"id": "x"}}), exit_action)
            for target in ("objective", "follow_pedro", "explore_Praia", "approach_MoradorPedro"):
                state["room"]["outside_targets"].append("approach_MoradorPedro")
                self.assertEqual(bot._leave_room_first(state, {exit_action: "door", target: "go"}, target, "x")[0], exit_action)
            self.assertEqual(bot._leave_room_first(state, {exit_action: "door", "approach_bed": "go"}, "approach_bed", "x")[0], "approach_bed")

    def test_recovery_inside_the_house_leaves_by_the_door_instead_of_probing_the_bed(self):
        # Acordou em casa com o objetivo lá fora e o robô já em recuperação (ao vivo, 08/10): ele
        # experimentava o E da cama, respondia "sim" e dormia de novo, manhã após manhã (#191).
        bot, state = self.player(), self.awake_with_finished_tutorial()
        state.update(home_interaction="cama", interaction_target="CasaDoJogador", objective={"id": "pedro_ponte_lenha", "alvo": [30, 0, 30]})
        bot.choose(dict(state), {"wait": "wait"}, {})      # arma os contadores do robô
        bot.recovery = True
        context = bot._context(state)
        for action in ("objective", "gather_lenha", "approach_MoradorPedro"):
            bot.coverage[(context, action)] = 5          # as rotas diretas já foram tentadas aqui
        actions = {"exit_home": "door", "interact": "sleep", "face_CasaDoJogador": "bed", "work_E": "work", "objective": "go",
                   "inspect_journal": "J", "wait": "wait"}
        task = {"step": {"id": "ponte_lenha", "meta": {"tipo": "juntar", "item": "lenha", "quantos": 36}}}
        picks = [bot.choose(dict(state), actions, task) for _ in range(3)]
        self.assertEqual(picks, ["exit_home"] * 3)
        self.assertNotIn("interact", picks)

    def test_target_inside_the_room_is_not_replaced_by_the_door(self):
        bot, state = self.player(), self.awake_with_finished_tutorial()
        state.update(home_interaction="cama", interaction_target="CasaDoJogador", farm={"awaiting_morning": True})
        actions = {"exit_home": "door", "interact": "sleep", "approach_bed": "bed"}
        self.assertEqual(bot.choose(state, actions, {}), "interact")

    def test_guide_walk_is_bounded_when_he_never_gets_closer(self):
        bot, state = self.player(), self.state()
        state.update(interior="", objective={}, journal={"ativas": []}, pedro={"conducting": False},
                     mission_chains=[{"key": "pedro", "name": "mirante", "main": True, "started": False, "completed": False, "locked": False}])
        actions = {"approach_MoradorPedro": "post", "wait": "wait", "observe": "look"}
        picks = [bot.choose(dict(state), actions, {}) for _ in range(10)]
        self.assertEqual(picks[:6], ["approach_MoradorPedro"] * 6)
        self.assertNotIn("approach_MoradorPedro", picks[6:])

    def test_corner_in_a_room_forces_the_door_then_probes_a_free_direction(self):
        bot, state = self.player(), self.state()
        state.update(interior="casa", objective={"id": "x", "alvo": [1, 0, 1]}, room={"name": "casa", "outside_targets": []},
                     directions={"left": {"blocked": False, "walk_endpoint": [-2, 0, 0], "walk_endpoint_walkable": True}})
        actions = {"exit_home": "door", "objective": "go", "walk_left": "left", "wait": "wait"}
        task = {"step": {"id": "x", "meta": {}}}
        picks = [bot.choose(dict(state), actions, task) for _ in range(7)]
        # Três tentativas de ir ao objetivo sem sair do lugar: a saída forçada vem duas vezes
        # e então o testador sonda uma direção livre, sem ficar repetindo.
        self.assertEqual(picks[:3], ["objective"] * 3)
        self.assertEqual(picks[3:5], ["exit_home", "exit_home"])
        self.assertEqual(picks[5], "walk_left")

    def test_farm_guide_after_sleep_leaves_house_before_following(self):
        bot, state = self.player(), self.state()
        state.update(energy=77.8, interior="casa", objective={"id": "pedro_fazenda_ida"},
                     pedro={"conducting": True, "guide_destination_reached": False})
        task = {"step": {"conduz": True, "lugar": "portao_da_fazenda", "meta": {}}}
        actions = {"exit_home": "door", "follow_pedro": "guide", "objective": "walk"}
        self.assertEqual(bot.choose(state, actions, task), "exit_home")
        state["interior"] = ""
        self.assertEqual(bot.choose(state, actions, task), "follow_pedro")

    def test_invitation_waits_for_morning_using_bed_without_low_energy(self):
        bot, state = self.player(), self.state()
        state.update(energy=80, interior="", farm={"awaiting_morning": True}, journal={"ativas": []},
                     mission_chains=[{"key": "pedro", "main": True, "locked": False, "started": False}])
        actions = {"enter_home": "door", "approach_bed": "bed", "follow_pedro": "guide", "interact": "E", "wait": "wait"}
        self.assertEqual(bot.choose(state, actions, {}), "enter_home")
        state.update(interior="casa", home_interaction="bau", interaction_target="CasaDoJogador")
        self.assertEqual(bot.choose(state, actions, {}), "approach_bed")
        state.update(home_interaction="cama")
        self.assertEqual(bot.choose(state, actions, {}), "interact")
        self.assertEqual(state["energy"], 80)
        state["farm"]["awaiting_morning"] = False
        state.update(interior="", interaction_target="Pedro")
        self.assertEqual(bot.choose(state, actions, {}), "interact")

    def test_exhausted_food_returns_through_door_then_bed_instead_of_futile_work(self):
        bot = self.player()
        state = self.state()
        state.update(energy=3, interior="", inventory={"slots": [], "food_items": []})
        task = {"step": {"meta": {"tipo": "juntar", "item": "lenha", "quantos": 54}}}
        actions = {"enter_home": "door", "approach_bed": "bed", "work_E": "hit", "wait": "wait"}
        self.assertEqual(bot.choose(state, actions, task), "enter_home")
        state.update(interior="casa", home_interaction="bau", interaction_target="CasaDoJogador")
        self.assertEqual(bot.choose(state, {**actions, "interact": "E"}, task), "approach_bed")
        state.update(home_interaction="cama")
        self.assertEqual(bot.choose(state, {**actions, "interact": "E"}, task), "interact")
        self.assertEqual(state["energy"], 3)
        self.assertEqual(state["inventory"]["slots"], [])

    def test_checkpoint_waits_for_work_to_finish_before_opening_pause(self):
        bot = self.player()
        state = self.state()
        bot.checkpoint_time, bot.checkpoint_materials = 0, 0
        state["seconds"] = 301
        state["interaction_candidates"] = [{"target": {"em_trabalho": True}}]
        self.assertEqual(bot.choose(state, {"inspect_pause": "Esc", "wait": "wait"}, {}), "wait")
        state["interaction_candidates"] = []
        self.assertEqual(bot.choose(state, {"inspect_pause": "Esc", "wait": "wait"}, {}), "inspect_pause")

    def test_checkpoint_uses_pause_cursor_confirm_and_observed_notice(self):
        bot = self.player()
        state = self.state()
        bot.checkpoint_time, bot.checkpoint_materials = 0, 0
        state["seconds"] = 301
        self.assertEqual(bot.choose(state, {"inspect_pause": "Esc", "wait": "wait"}, {}), "inspect_pause")
        state.update(screen="menu_pausa", pause_menu={"cursor": 0, "save_index": 4, "notice": ""})
        ui = {"screen_down": "S", "screen_up": "W", "confirm_screen": "E", "close_screen": "Esc"}
        self.assertEqual(bot.choose(state, ui, {}), "screen_down")
        state["pause_menu"]["cursor"] = 4
        self.assertEqual(bot.choose(state, ui, {}), "confirm_screen")
        state["pause_menu"]["notice"] = "Partida guardada na vaga 1."
        self.assertEqual(bot.choose(state, ui, {}), "close_screen")
        self.assertEqual(bot.checkpoint_notice, state["pause_menu"]["notice"])
        self.assertFalse(bot.checkpoint_pending)

    def test_checkpoint_after_material_batch_does_not_repeat_each_frame(self):
        bot = self.player()
        state = self.state()
        bot.checkpoint_time, bot.checkpoint_materials = state["seconds"], 0
        state["inventory"]["slots"] = [{"id": "lenha", "qtd": 8}]
        self.assertEqual(bot.choose(state, {"inspect_pause": "Esc", "wait": "wait"}, {}), "inspect_pause")
        state.update(screen="menu_pausa", pause_menu={"cursor": 4, "save_index": 4, "notice": "Não consegui salvar."})
        self.assertEqual(bot.choose(state, {"close_screen": "Esc"}, {}), "close_screen")
        self.assertEqual(bot.checkpoint_notice, "Não consegui salvar.")
        state.update(screen="")
        self.assertEqual(bot.choose(state, {"inspect_pause": "Esc", "wait": "wait"}, {}), "wait")

    def test_partial_resource_hits_renew_work_without_mission_or_inventory_change(self):
        bot = self.player()
        state = self.state()
        state["inventory"]["in_hand"] = "picareta"
        state["objective"]["alvo"] = [1, 0, 1]
        state.update(interaction_target="Recursos3D", interaction_candidates=[{"source": "Recursos3D", "target": {"ponto": [1, 0, 1]}}])
        task = {"step": {"meta": {"tipo": "juntar", "item": "pedra", "quantos": 11}}}
        for hit in range(8):
            state["resource_work"] = {"lajedo": hit}
            self.assertEqual(bot.choose(state, {"work_E": "hit", "objective": "route", "wait": "wait"}, task), "work_E")
        state["interaction_candidates"][0]["target"]["em_trabalho"] = True
        self.assertEqual(bot.choose(state, {"work_E": "hit", "wait": "wait"}, task), "wait")

    def test_repeated_physical_contour_turns_toward_source_instead_of_overshooting(self):
        bot = self.player()
        state = self.state()
        goal = state["objective"]["id"]
        state["position"] = [0, 0, -10]
        state["directions"] = {
            "backward": {"blocked": False, "walk_endpoint_walkable": True, "walk_endpoint": [0, 0, -15]},
            "right": {"blocked": False, "walk_endpoint_walkable": True, "walk_endpoint": [5, 0, -10]}}
        bot.escape_leg = {"goal": goal, "origin": [0, 0, 0], "action": "walk_backward", "limit": 24, "target": [10, 0, -10]}
        self.assertEqual(bot.choose(state, {"walk_backward": "S", "walk_right": "D", "wait": "wait"}, {}), "walk_right")

    def test_gather_route_oscillation_falls_back_to_normal_clear_direction(self):
        bot = self.player()
        state = self.state()
        state["resource_targets"] = {"lenha": [40, 0, 0]}
        state["directions"] = {"right": {"blocked": False, "walk_endpoint_walkable": True, "walk_endpoint": [5, 0, 0]}}
        task = {"step": {"meta": {"tipo": "juntar", "itens": {"lenha": 12}}}}
        actions = {"gather_lenha": "route", "walk_right": "move", "wait": "wait"}
        self.assertEqual(bot.choose(state, actions, task), "gather_lenha")
        state["position"] = [-1, 0, 0]
        self.assertEqual(bot.choose(state, actions, task), "gather_lenha")
        state["position"] = [-2, 0, 0]
        self.assertEqual(bot.choose(state, actions, task), "walk_right")
        self.assertEqual(bot.escape_leg["target"], [40, 0, 0])

    def test_group_raw_material_for_direct_requirement_and_observed_recipe_yield(self):
        state = self.state()
        state.update(resource_targets={"lenha": [20, 0, 0]}, world_map={"Oficina": [0, 0, 0]},
                     crafting={"Oficina": [{"id": "tabua", "requirements": {"rende": 2, "custo": {"lenha": 3}}}]})
        state["inventory"]["slots"] = [{"id": "lenha", "qtd": 20}, {"id": "tabua", "qtd": 2}]
        task = {"step": {"meta": {"tipo": "juntar", "itens": {"tabua": 8, "lenha": 12}}}}
        actions = {"gather_lenha": "route", "inspect_journal": "recipes", "wait": "wait"}
        self.assertEqual(self.player().choose(state, actions, task), "gather_lenha")
        state["inventory"]["slots"][0]["qtd"] = 21
        self.assertEqual(self.player().choose(state, actions, task), "inspect_journal")

    def test_repeated_route_failure_extends_bounded_physical_contour(self):
        bot = self.player()
        state = self.state()
        state["objective"]["alvo"] = [40, 0, 0]
        state["directions"] = {"right": {"blocked": False, "walk_endpoint_walkable": True, "walk_endpoint": [5, 0, 0]}}
        actions = {"walk_right": "move", "objective": "route", "wait": "wait"}
        task = {"last_action_failed": ["objective"]}
        bot.last_action = "objective"
        bot.choose(state, actions, task)
        bot.escape_leg = {}
        bot.last_action = "objective"
        bot.choose(state, actions, task)
        self.assertEqual(bot.escape_leg.get("limit"), 16)
        state["position"] = [9, 0, 0]
        self.assertEqual(bot.choose(state, actions, {}), "walk_right")
        state["position"] = [39, 0, 0]
        bot.choose(state, actions, {})
        self.assertFalse(bot.escape_leg)

    def test_compound_materials_without_nearby_resource_dont_seek_home_chest(self):
        state = self.state()
        task = {"step": {"lugar": "oficina", "meta": {"tipo": "juntar", "itens": {"lenha": 12, "tabua": 8}}}}
        bot = self.player()
        actions = {"enter_home": "door", "objective": "tree route", "wait": "wait"}
        self.assertEqual(bot.choose(state, actions, task), "objective")

    def test_compound_material_requirement_prioritizes_missing_raw_wood(self):
        state = self.state()
        state["inventory"]["in_hand"] = "machado"
        state["objective"]["alvo"] = [1, 0, 1]
        state.update(interaction_target="Pedro", interaction_candidates=[{"source": "ArvoresInfo", "kind": "tree", "target": {"ponto": [1, 0, 1]}}])
        task = {"step": {"meta": {"tipo": "juntar", "itens": {"lenha": 12, "tabua": 8}}}}
        self.assertEqual(self.player().choose(state, {"face_ArvoresInfo": "turn", "interact": "talk", "objective": "route"}, task), "face_ArvoresInfo")

    def test_completed_guide_chain_probes_next_unlocked_story_through_conversation(self):
        state = self.state()
        state.update(interaction_target="Pedro", mission_chains=[{"key": "pedro", "name": "mirante", "main": True, "started": False, "completed": False, "locked": False}])
        state["journal"] = {"ativas": [{"id": "zefa", "principal": True, "dono": "zefa"}]}
        bot = self.player()
        self.assertEqual(bot.choose(state, {"interact": "E", "follow_pedro": "route"}, {}), "interact")
        state["mission_chains"][0]["locked"] = True
        self.assertNotEqual(bot.choose(state, {"interact": "E", "follow_pedro": "route", "wait": "wait"}, {}), "follow_pedro")

    def test_collision_escape_prefers_clear_direction_toward_objective(self):
        bot = self.player()
        bot.last_action = "objective"
        state = self.state()
        state["objective"]["alvo"] = [10, 0, 0]
        state["directions"] = {"left": {"blocked": False, "walk_endpoint_walkable": True, "walk_endpoint": [-5, 0, 0]}, "right": {"blocked": False, "walk_endpoint_walkable": True, "walk_endpoint": [5, 0, 0]}}
        self.assertEqual(bot.choose(state, {"walk_left": "A", "walk_right": "D", "objective": "route"}, {"last_action_failed": ["objective"]}), "walk_right")
        self.assertEqual(bot.escape_leg["action"], "walk_right")

    def test_exhausted_worker_eats_real_food_using_inventory_controls(self):
        state = self.state()
        state["energy"] = 1
        state["inventory"].update(slots=[{}, {"id": "beiju", "qtd": 2}], food_items=["beiju"])
        actions = {"inspect_inventory": "I", "work_E": "E", "screen_right": "D", "screen_use": "F"}
        bot = self.player()
        self.assertEqual(bot.choose(state, actions, {}), "inspect_inventory")
        state.update(screen="mochila", inventory_screen={"cursor": 0, "chest": []})
        self.assertEqual(bot.choose(state, actions, {}), "screen_right")
        state["inventory_screen"]["cursor"] = 1
        self.assertEqual(bot.choose(state, actions, {}), "screen_use")
        state["energy"] = 25
        actions["close_screen"] = "Esc"
        self.assertEqual(bot.choose(state, actions, {}), "close_screen")

    def test_new_player_name_is_confirmed_before_opening_buttons(self):
        self.assertEqual(self.player().choose(self.state(), {"name_player": "type", "button_0": "Continue"}, {}), "name_player")

    def test_other_main_quest_does_not_replace_first_pending_story_chain(self):
        state = self.state()
        state["objective"].update(id="zefa_ervas", principal=True)
        state["journal"] = {"ativas": [{"id": "ponte_lenha", "principal": True}, {"id": "zefa_ervas", "principal": True}]}
        self.assertEqual(self.player().choose(state, {"inspect_journal": "J", "objective": "route"}, {}), "inspect_journal")

    def test_new_guide_step_appended_after_other_main_quest_keeps_campaign_focus(self):
        state = self.state()
        state["objective"].update(id="zefa_ervas", principal=True)
        state["journal"] = {"ativas": [{"id": "zefa_ervas", "principal": True, "dono": "zefa"}, {"id": "pedro_tabuas", "principal": True, "dono": "pedro"}]}
        self.assertEqual(self.player().choose(state, {"inspect_journal": "J", "objective": "route"}, {}), "inspect_journal")

    def test_tree_resource_is_worked_using_normal_controls_after_finite_logs_run_out(self):
        bot = self.player()
        state = self.state()
        state["inventory"]["in_hand"] = "machado"
        state["objective"]["alvo"] = [1, 0, 1]
        state.update(interaction_target="Pedro", interaction_candidates=[{"source": "ArvoresInfo", "kind": "tree", "target": {"ponto": [1, 0, 1]}}])
        actions = {"face_ArvoresInfo": "turn", "work_E": "E", "interact": "talk", "objective": "route"}
        task = {"step": {"meta": {"tipo": "juntar", "item": "lenha", "quantos": 36}}}
        self.assertEqual(bot.choose(state, actions, task), "face_ArvoresInfo")
        state["interaction_target"] = "ArvoresInfo"
        self.assertEqual(bot.choose(state, actions, task), "work_E")
        state["interaction_candidates"][0]["target"]["em_trabalho"] = True
        actions["wait"] = "wait"
        self.assertEqual(bot.choose(state, actions, task), "wait")

    def test_exploration_restores_main_story_focus_through_journal_controls(self):
        bot = self.player()
        state = self.state()
        state["objective"]["principal"] = False
        state["journal"] = {"ativas": [{"id": "ponte_lenha", "principal": True}, {"id": "facao", "principal": False}]}
        actions = {"inspect_journal": "J", "screen_tab": "Tab", "screen_up": "W", "confirm_screen": "E", "objective": "route"}
        self.assertEqual(bot.choose(state, actions, {}), "inspect_journal")
        state.update(screen="painel", panel={"tab": 3, "allowed_tabs": [0, 3], "cursor": 0})
        self.assertEqual(bot.choose(state, actions, {}), "screen_tab")
        state["panel"].update(tab=0, cursor=1, entries=state["journal"]["ativas"])
        self.assertEqual(bot.choose(state, actions, {}), "screen_up")
        state["panel"]["cursor"] = 0
        self.assertEqual(bot.choose(state, actions, {}), "confirm_screen")

    def test_active_guided_walk_is_not_abandoned_after_journal_focus_changed(self):
        bot = self.player()
        state = self.state()
        state["pedro"] = {"conducting": True, "guide_destination_reached": False}
        task = {"step": {"meta": {"tipo": "juntar", "item": "facao", "quantos": 1}}}
        self.assertEqual(bot.choose(state, {"follow_pedro": "guide", "objective": "workshop"}, task), "follow_pedro")

    def test_failed_route_probes_clear_physical_direction_before_distant_target(self):
        bot = self.player()
        state = self.state()
        state.update(seconds=100, directions={
            "forward": {"blocked": True, "walk_endpoint_walkable": True},
            "left": {"blocked": False, "walk_endpoint_walkable": True}},
            world_map={"Oficina": [100, 0, 0]})
        bot.choose(state, {"objective": "walk"}, {})
        task = {"last_action_failed": ["objective"]}
        self.assertEqual(bot.choose(state, {"walk_forward": "W", "walk_left": "A", "explore_Oficina": "route"}, task), "walk_left")
        state["position"][0] += 3
        self.assertEqual(bot.choose(state, {"walk_left": "A", "objective": "route"}, {}), "walk_left")
        state["directions"]["left"]["blocked"] = True
        self.assertNotEqual(bot.choose(state, {"walk_left": "A", "objective": "route", "wait": "wait"}, {}), "walk_left")

    def test_multiple_material_requirements_pick_missing_live_recipe(self):
        bot = self.player()
        state = self.state()
        state.update(screen="painel", panel={"tab": 3, "cursor": 0},
                     crafting={"Oficina": [{"id": "tabua", "impediment": ""}, {"id": "corda", "impediment": ""}]})
        state["inventory"]["slots"].append({"id": "tabua", "qtd": 12})
        task = {"step": {"meta": {"tipo": "juntar", "itens": {"tabua": 12, "corda": 4}}}}
        self.assertEqual(bot.choose(state, {"screen_down": "S", "close_screen": "Esc"}, task), "screen_down")

    def test_wood_uses_live_total_and_equips_existing_axe(self):
        bot = self.player()
        state = self.state()
        state["objective"]["total"] = 36
        state["inventory"]["slots"] += [{"id": "lenha", "qtd": 4}, {"id": "machado", "qtd": 1}]
        task = {"step": {"meta": {"tipo": "juntar", "item": "lenha", "equivale": {"tabua": 12, "corda": 4}}}}
        self.assertEqual(bot.choose(state, {"hand_3": "equip", "objective": "walk"}, task), "hand_3")
    def test_after_completed_chain_leaves_home_before_asking_guide(self):
        bot = self.player()
        state = self.state()
        state.update(interior="casa", objective={})
        self.assertEqual(bot.choose(state, {"exit_home": "door", "follow_pedro": "guide"}, {"step": {}}), "exit_home")

    def test_no_active_step_asks_actual_guide_instead_of_random_inventory(self):
        bot = self.player()
        state = self.state()
        state.update(objective={}, interaction_target="MoradorPedro")
        self.assertEqual(bot.choose(state, {"interact": "E", "inspect_inventory": "I"}, {"step": {}}), "interact")
    def test_reads_required_document_through_inventory_cursor_and_F(self):
        bot = self.player()
        state = self.state()
        state.update(screen="mochila", inventory_screen={"cursor": 0})
        state["inventory"]["slots"] = [{"id": "peixe", "qtd": 1}, {"id": "convite", "qtd": 1}]
        task = {"step": {"meta": {"tipo": "evento", "evento": "leu:convite"}}}
        actions = {"screen_right": "D", "screen_use": "F", "close_screen": "Esc"}
        self.assertEqual(bot.choose(state, actions, task), "screen_right")
        state["inventory_screen"]["cursor"] = 1
        self.assertEqual(bot.choose(state, actions, task), "screen_use")
    def test_cooking_goes_to_actual_fire_anchor(self):
        bot = self.player()
        state = self.state()
        state.update(crafting={"Cozinha": [{"id": "peixe_assado", "impediment": ""}]},
                     world_map={"Fogueira": [30, 0, 0]})
        task = {"step": {"meta": {"tipo": "evento", "evento": "cozinhou:peixe_assado"}}}
        self.assertEqual(bot.choose(state, {"explore_Fogueira": "walk", "objective": "walk"}, task), "explore_Fogueira")
    def test_cooking_event_uses_recipe_even_with_an_existing_dish(self):
        bot = self.player()
        state = self.state()
        state.update(screen="painel", panel={"tab": 4, "cursor": 0},
                     crafting={"Cozinha": [{"id": "peixe_assado", "impediment": ""}]})
        state["inventory"]["slots"].append({"id": "peixe_assado", "qtd": 1})
        task = {"step": {"meta": {"tipo": "evento", "evento": "cozinhou:peixe_assado"}}}
        self.assertEqual(bot.choose(state, {"confirm_screen": "E", "close_screen": "Esc"}, task), "confirm_screen")
    def test_building_selects_required_work_by_live_entries(self):
        bot = self.player()
        state = self.state()
        state.update(screen="painel", panel={"tab": 2, "allowed_tabs": [0, 2], "construction": "poco",
                                            "entries": ["outra_obra", "poco_corda"], "cursor": 0})
        task = {"step": {"meta": {"tipo": "obra", "construcao": "poco", "obra": "poco_corda"}}}
        actions = {"confirm_screen": "E", "screen_down": "S", "close_screen": "Escape"}
        self.assertEqual(bot.choose(state, actions, task), "screen_down")
        state["panel"]["cursor"] = 1
        self.assertEqual(bot.choose(state, actions, task), "confirm_screen")

    def test_building_never_confirms_unrelated_or_absent_work(self):
        bot = self.player()
        state = self.state()
        state.update(screen="painel", panel={"tab": 2, "allowed_tabs": [0, 2], "construction": "ponte",
                                            "entries": ["outra_obra"], "cursor": 0})
        task = {"step": {"meta": {"tipo": "obra", "construcao": "poco", "obra": "poco_corda"}}}
        self.assertEqual(bot.choose(state, {"confirm_screen": "E", "close_screen": "Escape"}, task), "close_screen")
    def test_distant_work_is_not_replaced_by_unrelated_interface_probes(self):
        bot = self.player()
        state = self.state()
        state["objective"]["alvo"] = [200, 0, 0]
        task = {"step": {"meta": {"tipo": "obra"}, "raio": 8}}
        bot.choose(state, {"objective": "walk", "inspect_inventory": "inspect"}, task)
        state["seconds"] = 80
        self.assertEqual(bot.choose(state, {"objective": "walk", "inspect_inventory": "inspect"},
                                    task), "objective")
    def test_long_trip_keeps_route_when_distance_decreases(self):
        bot = self.player()
        state = self.state()
        state["objective"]["alvo"] = [200, 0, 0]
        actions = {"objective": "walk", "inspect_inventory": "inspect", "wait": "wait"}
        bot.choose(state, actions, {})
        state.update(seconds=45, position=[30, 0, 0])
        self.assertEqual(bot.choose(state, actions, {}), "objective")

    def test_unmoving_long_trip_still_recovers(self):
        bot = self.player()
        state = self.state()
        state["objective"]["alvo"] = [200, 0, 0]
        actions = {"objective": "walk", "inspect_inventory": "inspect", "wait": "wait"}
        bot.choose(state, actions, {})
        state["seconds"] = 45
        self.assertNotEqual(bot.choose(state, actions, {}), "objective")
    def test_inside_home_exits_before_external_crafting(self):
        bot = self.player()
        state = self.state()
        state.update(interior="casa", crafting={"Oficina": [{"id": "corda", "impediment": ""}]})
        self.assertEqual(bot.choose(state, {"exit_home": "door", "explore_Oficina": "walk"},
                                    {"step": {"meta": {"item": "corda", "quantos": 1}}}), "exit_home")
    def test_recipe_tab_absent_closes_instead_of_looping(self):
        bot = self.player()
        state = self.state()
        state.update(screen="painel", panel={"tab": 0, "allowed_tabs": [0]},
                     crafting={"Oficina": [{"id": "corda", "impediment": ""}]})
        task = {"step": {"meta": {"item": "corda", "quantos": 1}}}
        self.assertEqual(bot.choose(state, {"screen_tab": "tab", "close_screen": "close"}, task), "close_screen")

    def test_old_bridge_tab_search_has_finite_limit(self):
        bot = self.player()
        state = self.state()
        state.update(screen="painel", panel={"tab": 0},
                     crafting={"Oficina": [{"id": "corda", "impediment": ""}]})
        task = {"step": {"meta": {"item": "corda", "quantos": 1}}}
        results = [bot.choose(state, {"screen_tab": "tab", "close_screen": "close"}, task) for _ in range(9)]
        self.assertEqual(results[-1], "close_screen")

    def test_rebuilt_panel_node_names_do_not_reset_coverage(self):
        bot = self.player()
        state = self.state()
        state["panel"] = {"tab": 0, "cursor": 0, "rows": ["@Button@1"]}
        signature = bot._context(state)
        state["panel"]["rows"] = ["@Button@2"]
        self.assertEqual(bot._context(state), signature)
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

    def axe_in_the_backpack(self):
        """A picareta na mão e o machado só na mochila (vaga 12): o caso da lenha parada em 2/36 (#207)."""
        slots = [{} for _ in range(30)]
        slots[0], slots[1], slots[12] = {"id": "balde", "qtd": 1}, {"id": "picareta", "qtd": 1}, {"id": "machado", "qtd": 1}
        state = self.state()
        state["objective"].update(id="pedro_lenha", total=36)
        state["inventory"] = {"in_hand": "picareta", "slots": slots}
        self.refresh_hand_bar(state)
        return state

    @staticmethod
    def refresh_hand_bar(state):
        families = {"machado_de_aco": "machado"}
        slots = state["inventory"]["slots"]
        state["inventory"]["hand_bar"] = [{"slot": i, "id": slots[i].get("id", ""), "family": families.get(slots[i].get("id", ""), slots[i].get("id", ""))}
                                          for i in range(min(10, len(slots)))]

    def swap_in_the_screen(self, state, held, cursor):
        slots = state["inventory"]["slots"]
        if held >= 0 and cursor != held:
            slots[held], slots[cursor] = slots[cursor], slots[held]
            self.refresh_hand_bar(state)

    def test_axe_only_in_the_backpack_goes_to_the_hand_bar_then_is_selected(self):
        # "Ponha na mão: Machado" (#207): abre a mochila, pega o machado, solta na barra, fecha, seleciona.
        bot, state = self.player(), self.axe_in_the_backpack()
        task = {"step": {"meta": {"tipo": "juntar", "item": "lenha", "quantos": 36}}}
        actions = {name: name for name in ("objective", "inspect_inventory", "close_screen", "confirm_screen", "screen_up", "screen_down",
                                             "screen_left", "screen_right", "hand_0", "hand_1", "hand_2", "hand_3", "work_E", "wait")}
        state["tool_requirement"] = {"alvo": "Tronco", "ferramenta": "machado", "situacao": "na_mochila", "vaga": 12, "dica": "ponha na mão: Machado"}
        picks = [bot.choose(dict(state), actions, task)]
        self.assertEqual(picks[0], "inspect_inventory")
        state.update(screen="mochila", inventory_screen={"cursor": 0, "held_slot": -1, "chest": []})
        for _ in range(12):
            pick = bot.choose(dict(state), actions, task)
            picks.append(pick)
            ui = state.get("inventory_screen", {})
            if pick == "screen_down":
                ui["cursor"] += 10
            elif pick == "screen_up":
                ui["cursor"] -= 10
            elif pick == "screen_right":
                ui["cursor"] += 1
            elif pick == "screen_left":
                ui["cursor"] -= 1
            elif pick == "confirm_screen":
                if ui["held_slot"] < 0:
                    ui["held_slot"] = ui["cursor"]
                else:
                    self.swap_in_the_screen(state, ui["held_slot"], ui["cursor"])
                    ui["held_slot"] = -1
            elif pick == "close_screen":
                state.pop("screen")
                state.pop("inventory_screen")
            elif pick.startswith("hand_"):
                break
        self.assertEqual(picks[-1], "hand_2", picks)
        self.assertLessEqual(len(picks), 12)
        self.assertIn("confirm_screen", picks)
        # Com o machado na mão o robô volta ao recurso, sem mexer na mochila de novo.
        state["inventory"]["in_hand"] = "machado"
        state["tool_requirement"].update(situacao="na_mao", vaga=-1)
        self.assertEqual(bot.choose(dict(state), actions, task), "objective")
        # E, chegando ao tronco caído com o machado na mão, corta: vira o golpe (E segurado).
        state.update(interaction_target="Recursos3D", objective=dict(state["objective"], alvo=[1, 0, 1]),
                     interaction_candidates=[{"source": "Recursos3D", "kind": "log", "target": {"ponto": [1, 0, 1]}}])
        self.assertEqual(bot.choose(dict(state), actions, task), "work_E")

    def test_stuck_wood_at_2_of_36_is_worked_within_a_dozen_actions_instead_of_fifty_waits(self):
        # O trecho de ~50 ações parado em 2/36 (#201, caso da escada da #183): o testador alternava
        # explore e wait ao lado do tronco porque a picareta estava na mão e o machado na mochila.
        bot, state = self.player(), self.axe_in_the_backpack()
        state["objective"].update(feito=2, total=36, alvo=[1, 0, 1])
        state.update(interaction_target="Recursos3D", interaction_candidates=[{"source": "Recursos3D", "kind": "log", "target": {"ponto": [1, 0, 1]}}])
        state["tool_requirement"] = {"alvo": "Tronco", "ferramenta": "machado", "situacao": "na_mochila", "vaga": 12, "dica": "ponha na mão: Machado"}
        state["last_refusal"] = {"motivo": "Precisa de Machado.", "ferramenta": "machado", "situacao": "na_mochila", "ago_ms": 400}
        task = {"step": {"meta": {"tipo": "juntar", "item": "lenha", "quantos": 36}}}
        actions = {name: name for name in ("objective", "inspect_inventory", "close_screen", "confirm_screen", "screen_up", "screen_down",
                                             "screen_left", "screen_right", "hand_0", "hand_1", "hand_2", "hand_3", "work_E", "interact", "wait", "explore_Praia")}
        picks = []
        for _ in range(50):
            pick = bot.choose(dict(state), actions, task)
            picks.append(pick)
            ui = state.get("inventory_screen", {})
            if pick in ("screen_down", "screen_up", "screen_right", "screen_left"):
                ui["cursor"] += {"screen_down": 10, "screen_up": -10, "screen_right": 1, "screen_left": -1}[pick]
            elif pick == "inspect_inventory":
                state.update(screen="mochila", inventory_screen={"cursor": 0, "held_slot": -1, "chest": []})
            elif pick == "confirm_screen":
                if ui["held_slot"] < 0:
                    ui["held_slot"] = ui["cursor"]
                else:
                    self.swap_in_the_screen(state, ui["held_slot"], ui["cursor"])
                    ui["held_slot"] = -1
            elif pick == "close_screen":
                state.pop("screen", None)
                state.pop("inventory_screen", None)
            elif pick.startswith("hand_"):
                state["inventory"]["in_hand"] = state["inventory"]["slots"][int(pick[5:])]["id"]
                state["tool_requirement"].update(situacao="na_mao", vaga=-1)
                state["last_refusal"] = {}
            elif pick in ("work_E", "interact"):
                break
        self.assertIn(picks[-1], ("work_E", "interact"), picks)
        self.assertLessEqual(len(picks), 14, picks)
        self.assertEqual(state["inventory"]["in_hand"], "machado")
        self.assertNotIn("wait", picks)

    def test_refusal_as_data_selects_the_tool_slot_in_the_bar(self):
        # "Ponha na mão"/"Precisa de" lidos como dado: vale até com o machado de aço, que é da família do machado.
        bot, state = self.player(), self.state()
        state["inventory"] = {"in_hand": "balde", "slots": [{"id": "balde", "qtd": 1}, {"id": "picareta", "qtd": 1}, {}, {"id": "machado_de_aco", "qtd": 1}]}
        self.refresh_hand_bar(state)
        state["last_refusal"] = {"motivo": "Ponha na mão: Machado.", "ferramenta": "machado", "situacao": "na_mochila", "ago_ms": 900}
        actions = {"hand_0": "h", "hand_1": "h", "hand_3": "h", "interact": "E", "wait": "wait"}
        self.assertEqual(bot.choose(state, actions, {}), "hand_3")
        state["inventory"]["in_hand"] = "machado_de_aco"
        self.assertNotEqual(bot.choose(state, actions, {}), "hand_3")

    def test_hint_of_the_E_key_selects_the_tool_after_a_try(self):
        bot, state = self.player(), self.axe_in_the_backpack()
        state["inventory"]["slots"][3], state["inventory"]["slots"][12] = state["inventory"]["slots"][12], {}
        self.refresh_hand_bar(state)
        state["tool_requirement"] = {"alvo": "Tronco", "ferramenta": "machado", "situacao": "na_barra", "vaga": 3, "dica": "selecione Machado (4)"}
        actions = {"hand_3": "h", "interact": "E", "wait": "wait", "observe": "F"}
        bot.last_action = "interact"
        self.assertEqual(bot.choose(state, actions, {}), "hand_3")

    def test_missing_tool_is_noted_in_the_reason_and_not_looped(self):
        bot, state = self.player(), self.state()
        state["last_refusal"] = {"motivo": "Precisa de Machado.", "ferramenta": "machado", "situacao": "falta", "ago_ms": 500}
        actions = {"objective": "go", "wait": "wait", "observe": "F"}
        for _ in range(3):
            self.assertIn(bot.choose(state, actions, {}), actions)
        self.assertIn("Falta ferramenta machado", bot.reason)

    def test_replan_after_manual_control_drops_the_old_plan(self):
        # F7 devolvido (#206): a rota, o contorno e a troca de ferramenta velhos não valem mais.
        bot, state = self.player(), self.axe_in_the_backpack()
        task = {"step": {"meta": {"tipo": "juntar", "item": "lenha", "quantos": 36}}}
        actions = {"inspect_inventory": "I", "objective": "go", "hand_1": "h", "wait": "wait"}
        self.assertEqual(bot.choose(dict(state), actions, task), "inspect_inventory")
        self.assertEqual(bot.equipping, "machado")
        bot.navigation_leg = {"goal": "x", "action": "objective", "target": [9, 0, 9], "distance": 12}
        bot.escape_leg = {"action": "walk_left", "origin": [0, 0, 0], "goal": "x"}
        bot.replan()
        self.assertEqual((bot.equipping, bot.navigation_leg, bot.escape_leg, bot.last_action), ("", {}, {}, ""))
        self.assertFalse(bot.recovery)
        # Com o machado agora na mão (o humano o pôs), o robô não reabre a mochila: segue ao recurso.
        state["inventory"]["in_hand"] = "machado"
        self.assertEqual(bot.choose(dict(state), actions, task), "objective")

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
        task = {"step": {"lugar": "casa_de_taipa", "meta": {"tipo": "juntar", "itens": {"enxada": 1}}}}
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
    def test_report_links_compressed_frames_and_legacy_png(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            (directory / "eventos.jsonl").write_text("", encoding="utf-8")
            for name in ("quadro_0001.png", "quadro_0031.jpg"):
                (directory / name).write_bytes(b"frame")
            report = generate(directory).read_text(encoding="utf-8")
            self.assertIn("](quadro_0001.png)", report)
            self.assertIn("](quadro_0031.jpg)", report)

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

    def test_report_lists_manual_control_with_duration_and_effect(self):
        # F7 (#206): cada trecho em que o humano jogou entra no relatório com a duração e o que mudou.
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            slots_before = [{"id": "picareta", "qtd": 1}, {"id": "machado", "qtd": 1}]
            before = {"position": [0, 0, 0], "objective": {"id": "pedro_lenha", "feito": 2, "total": 36},
                      "inventory": {"in_hand": "picareta", "slots": slots_before}}
            after = {"position": [3, 0, 4], "objective": {"id": "pedro_lenha", "feito": 5, "total": 36},
                     "inventory": {"in_hand": "machado", "slots": slots_before + [{"id": "lenha", "qtd": 3}]}}
            records = [{"kind": "game_ready", "elapsed": 1},
                       {"kind": "manual_control", "elapsed": 100, "phase": "start", "before": before, "capture": "quadro_0100.jpg", "last_action": "wait"},
                       {"kind": "manual_control", "elapsed": 125, "phase": "end", "reason": "f7", "duration_s": 25.0,
                        "before": before, "after": after, "capture": "quadro_0125.jpg", "start_capture": "quadro_0100.jpg"},
                       {"kind": "manual_control", "elapsed": 200, "phase": "start", "before": after, "last_action": "objective"}]
            (directory / "eventos.jsonl").write_text("\n".join(json.dumps(r) for r in records) + "\n", encoding="utf-8")
            report = generate(directory).read_text(encoding="utf-8")
            self.assertIn("## Controle manual (F7)", report)
            self.assertIn("por 25.0 s", report)
            self.assertIn("missão pedro_lenha 2/36 → pedro_lenha 5/36", report)
            self.assertIn("+3 lenha", report)
            self.assertIn("mão: picareta → machado", report)
            self.assertIn("deslocou 5.0 unidades", report)
            self.assertIn("Última ação do testador antes: wait", report)
            self.assertIn("](quadro_0125.jpg)", report)
            self.assertIn("ainda está jogando", report)

    def test_report_lists_the_traveller_hidden_by_the_camera_with_capture(self):
        # #201: o viajante encoberto além do aceitável vira achado, com tempo, lugar e captura.
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            records = [{"kind": "game_ready", "elapsed": 1},
                       {"kind": "achado", "elapsed": 90, "type": "viajante_encoberto", "duration_s": 2.4, "action": "wait",
                        "position": [10.0, 0.0, -3.5], "capture": "quadro_0089.jpg"}]
            (directory / "eventos.jsonl").write_text(chr(10).join(json.dumps(r) for r in records) + chr(10), encoding="utf-8")
            report = generate(directory).read_text(encoding="utf-8")
            self.assertIn("## Viajante encoberto pela câmera", report)
            self.assertIn("encoberto por 2.4 s", report)
            self.assertIn("](quadro_0089.jpg)", report)
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / "eventos.jsonl").write_text("", encoding="utf-8")
            self.assertIn("não ficou encoberto por mais de 1,5 s", generate(Path(folder)).read_text(encoding="utf-8"))

    def test_report_without_manual_control_says_so(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            (directory / "eventos.jsonl").write_text("", encoding="utf-8")
            self.assertIn("Nenhuma vez o humano assumiu o controle", generate(directory).read_text(encoding="utf-8"))

    def test_report_lists_clock_stops_with_last_action_and_capture(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            (directory / "eventos.jsonl").write_text("", encoding="utf-8")
            clean = generate(directory).read_text(encoding="utf-8")
            self.assertIn("## Relógio parado", clean)
            self.assertIn("Nenhum relógio parado", clean)
            stop = {"kind": "achado", "type": "relogio_parado", "elapsed": 391.5, "reason": "pausado", "action": "follow_pedro",
                    "time": "06:00", "speed": 2, "held_by": [], "capture": "quadro_0391.jpg"}
            (directory / "eventos.jsonl").write_text(json.dumps(stop) + chr(10), encoding="utf-8")
            report = generate(directory).read_text(encoding="utf-8")
            self.assertNotIn("Nenhum relógio parado", report)
            self.assertIn("relógio parado às 06:00", report)
            self.assertIn("Dia.pausado", report)
            self.assertIn("Última ação: follow_pedro", report)
            self.assertIn("](quadro_0391.jpg)", report)

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
