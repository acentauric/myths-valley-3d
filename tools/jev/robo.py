"""Local state-based player. Explicit rules, no model API and no hidden progress."""
from collections import Counter
import json
import time


# O testador nunca mexe no relógio do jogador (#192): pausar, retomar, acelerar e
# adiantar a hora são escolhas dele, e custam as conquistas da partida. Nada que
# nomeie esses controles entra na escolha, mesmo que a ponte um dia os ofereça.
ACOES_DO_RELOGIO = {"inspect_time"}
MARCAS_DO_RELOGIO = ("clock", "relogio", "relógio", "velocidade", "speed", "avançar a hora", "advance the hour")


def mexe_no_relogio(action, description=""):
    """A ação aperta um controle de tempo do jogador (pausa, velocidade, hora)?"""
    if action in ACOES_DO_RELOGIO or action.startswith(("clock_", "speed_", "time_")):
        return True
    text = str(description).lower()
    return action.startswith("button_") and any(mark in text for mark in MARCAS_DO_RELOGIO)


# O Pedro, depois do tutorial, é um morador no posto dele (#191): sem "follow_pedro",
# o testador vai até ele como a qualquer outro, por esta ação.
GUIDE_APPROACH = "approach_MoradorPedro"
# Ações que levam o testador para outro lugar; sem sair do lugar, contam como travado.
TRAVEL_ACTIONS = ("follow_pedro", "approach_", "explore_", "objective", "gather_", "walk_", "run_", "enter_home", "exit_")
STAY_INSIDE_ACTIONS = ("approach_bed", "approach_chest")
# Quantas ações seguidas o robô gasta para pôr uma ferramenta na mão antes de desistir (#207).
EQUIP_STEPS_LIMIT = 40
EXIT_ACTIONS = ("exit_home", "exit_room")


class JogadorAutomatico:
    def __init__(self):
        self.attempts = Counter()
        self.last_goal = None
        self.reason = ""
        self.last_observation = None
        self.repeated_observations = 0
        self.last_action = ""
        self.action_delay = 0.7
        self.work_delay = 1.4

    @staticmethod
    def _inventory(state):
        items = Counter()
        for slot in state.get("inventory", {}).get("slots", []):
            item = slot.get("id", slot.get("item", ""))
            if item:
                items[item] += int(slot.get("qtd", slot.get("quantidade", slot.get("q", 1))))
        return dict(sorted(items.items()))

    def _context(self, state):
        # Relógio e animações não tornam uma tentativa inútil uma novidade.
        return json.dumps({"zone": [round(v / 4) for v in state.get("position", [])],
                           "goal": [state.get("objective", {}).get("id"), state.get("objective", {}).get("feito")],
                           "target": state.get("interaction_target"),
                           "hand": state.get("inventory", {}).get("in_hand"),
                           "resource_work": state.get("resource_work", {}),
                           "items": self._inventory(state), "screen": state.get("screen"),
                           "panel": {k: state.get("panel", {}).get(k) for k in ("tab", "cursor", "allowed_tabs")}, "ui": state.get("inventory_screen", {})},
                          sort_keys=True)

    @staticmethod
    def _guide_walk(actions):
        """Como ir ao Pedro: seguindo, enquanto ele conduz; senão, aproximando como a um morador."""
        return "follow_pedro" if "follow_pedro" in actions else (GUIDE_APPROACH if GUIDE_APPROACH in actions else None)

    @staticmethod
    def _room_exit(actions):
        return next((a for a in EXIT_ACTIONS if a in actions), None)

    def _leave_room_first(self, state, actions, action, reason):
        """Dentro de um cômodo, o alvo de fora pede a porta primeiro (#191): a soleira de dentro,
        a saída, e só então a rota para o alvo. Vale para seguir, aproximar, explorar e objetivo."""
        exit_action = self._room_exit(actions)
        outside = (state.get("room") or {}).get("outside_targets", [])
        if exit_action and action != exit_action and action in outside:
            return exit_action, "Sair pela porta antes de ir a " + action + " (o alvo esta fora do comodo)"
        return action, reason

    # A FERRAMENTA QUE O ALVO PEDE (#207). Regra determinística, antes de qualquer IA: diante
    # de "Ponha na mão: X" (dica do E ou recusa) ou "Precisa de X", o robô acha X na barra de
    # mão e seleciona a vaga; se X está só na mochila, troca com uma vaga da barra pela tela da
    # mochila (E pega, E solta) e então seleciona; se X não existe, anota que falta.
    @staticmethod
    def _tool_family(state, item):
        """A família de um item da barra de mão ("machado_de_aco" é machado), ou ele mesmo."""
        for slot in state.get("inventory", {}).get("hand_bar", []):
            if item and slot.get("id") == item and slot.get("family"):
                return slot["family"]
        return item

    def _holds(self, state, family):
        return bool(family) and self._tool_family(state, state.get("inventory", {}).get("in_hand")) == family

    @staticmethod
    def _tool_places(state, family):
        """(vaga da barra, vaga da mochila) da ferramenta da família; -1 onde não há."""
        inv = state.get("inventory", {})
        slots = inv.get("slots", [])
        bar = next((s["slot"] for s in inv.get("hand_bar", []) if s.get("id") and s.get("family") == family), -1)
        if bar < 0:
            bar = next((i for i, s in enumerate(slots[:10]) if s.get("id", s.get("item")) == family), -1)
        asked = state.get("tool_requirement") or {}
        pack = int(asked.get("vaga", -1)) if asked.get("ferramenta") == family and asked.get("situacao") == "na_mochila" else -1
        if pack < 10:
            pack = next((i for i, s in enumerate(slots) if i >= 10 and s.get("id", s.get("item")) == family), -1)
        return bar, pack

    def _equip_tool(self, state, actions, select, family):
        """Próxima ação para pôr a ferramenta `family` na mão, ou None se já está nela (ou falta).
        Limitado: depois de EQUIP_STEPS_LIMIT ações sem a ferramenta chegar à mão, desiste (o
        relatório mostra a nota) e deixa o resto da escada decidir."""
        key = ("equip", family)
        if not family:
            return None
        if self.attempts[key] >= EQUIP_STEPS_LIMIT:
            self.equipping = ""
            self.tool_note = "Nao consegui pôr " + family + " na mao"
            return None
        action = self._equip_step(state, actions, select, family)
        if action:
            self.attempts[key] += 1
        elif self._holds(state, family):
            self.attempts[key] = 0
        return action

    def _equip_step(self, state, actions, select, family):
        screen = state.get("screen")
        if self._holds(state, family):
            was_equipping = self.equipping == family
            self.equipping = ""
            if was_equipping and screen:
                return select("close_screen", "Ferramenta na mao: fechar a mochila e voltar ao alvo")
            return None
        bar, pack = self._tool_places(state, family)
        if bar >= 0:
            self.equipping = family
            if screen or state.get("inventory_screen"):
                return select("close_screen", "Ferramenta ja esta na barra: fechar a mochila e seleciona-la")
            return select("hand_%d" % bar, "Selecionar na barra de mao a ferramenta que o alvo pede: " + family)
        if pack < 0:
            self.equipping = ""
            self.tool_note = "Falta ferramenta " + family
            if screen and state.get("inventory_screen"):
                return select("close_screen", "Fechar a mochila: nao ha onde pegar a ferramenta")
            return None
        self.equipping = family
        slots = state.get("inventory", {}).get("slots", [])
        if not screen:
            return select("inspect_inventory", "Ferramenta so na mochila: abrir a mochila para poe-la na barra de mao")
        ui = state.get("inventory_screen", {})
        if not ui or ui.get("chest"):
            return select("close_screen", "Fechar outra interface para acessar a mochila")
        cursor = int(ui.get("cursor", 0))
        held = ui.get("held_slot")
        held = -1 if held is None else int(held)
        empty = next((i for i in range(10) if i >= len(slots) or not slots[i].get("id", slots[i].get("item"))), 9)
        target = pack if held < 0 else (empty if held == pack else held)
        if cursor == target:
            return select("confirm_screen", ("Pegar a ferramenta " if held < 0 else "Soltar na barra de mao ") + family)
        if cursor >= max(len(slots), 30):
            return select("screen_left", "Voltar dos encaixes aos itens da mochila")
        if cursor // 10 != target // 10:
            return select("screen_down" if cursor // 10 < target // 10 else "screen_up", "Chegar a fileira da ferramenta")
        return select("screen_right" if cursor < target else "screen_left", "Chegar a vaga da ferramenta")

    def _tool_demanded(self, state):
        """A ferramenta que a recusa recente ou a dica do E, lidas como dado, mandam pôr na mão."""
        if self.equipping:
            return self.equipping
        refusal = state.get("last_refusal") or {}
        if refusal.get("ferramenta") and float(refusal.get("ago_ms", 1e9)) < 20000:
            return refusal["ferramenta"]
        asked = state.get("tool_requirement") or {}
        tried_the_target = self.last_action in ("interact", "work_E") or self.last_action.startswith("face_")
        if asked.get("ferramenta") and asked.get("situacao") in ("na_barra", "na_mochila") and tried_the_target:
            return asked["ferramenta"]
        return ""

    def replan(self):
        """O humano devolveu o controle (F7, #206): o plano velho (rota, contorno, tentativas, cobertura,
        ferramenta em troca) não vale mais. Fica só o que o robô já sabe do mundo (lugares visitados)."""
        self.attempts.clear()
        getattr(self, "coverage", Counter()).clear()
        self.navigation_leg, self.escape_leg = {}, {}
        self.equipping, self.tool_note = "", ""
        self.recovery = self.route_failed = False
        self.last_goal = self.last_observation = self.progress_signature = None
        self.repeated_observations = self.room_still = self.room_exit_tries = 0
        self.checkpoint_pending = False
        self.last_action = ""

    def _explore(self, state, actions, select):
        """Experimentar o que está ao alcance antes de ampliar a busca."""
        context = self._context(state)
        tried = self.coverage
        def fresh(action, limit=1):
            return action in actions and tried[(context, action)] < limit
        if state.get("screen"):
            # Percorrer seleção/abas uma vez por contexto; fechar após oito
            # sondagens, para não ficar preso numa interface sem resultado.
            if self.screen_probes >= 8:
                self.screen_probes = 0
                return select("close_screen", "Exploração: encerrar sondagem da interface sem progresso")
            self.screen_probes += 1
            for action in ("confirm_screen", "screen_use", "screen_tab", "screen_down", "screen_right", "screen_up", "screen_left", "close_screen"):
                if fresh(action):
                    return select(action, "Exploração: testar uma seleção/aba ainda não experimentada")
            return select("close_screen", "Exploração: voltar ao mundo")
        self.screen_probes = 0
        # A route can cross a collider missing from the navigation mesh. Probe
        # a physically clear direction before retrying another distant route.
        failed = state.get("current_task", {}).get("last_action_failed", [])
        if self.last_action in failed or getattr(self, "route_failed", False):
            marker = state.get("objective", {}).get("alvo", [])
            if self.last_action.startswith("gather_"):
                marker = state.get("resource_targets", {}).get(self.last_action[7:], marker)
            def escape_rank(action):
                point = state.get("directions", {}).get(action[5:], {}).get("walk_endpoint", [])
                distance = sum((point[i] - marker[i]) ** 2 for i in (0, 2)) if len(point) == len(marker) == 3 else float("inf")
                return (distance, tried[(self.region, "escape", action)], action)
            for action in sorted((a for a in actions if a.startswith("walk_")), key=escape_rank):
                direction = state.get("directions", {}).get(action[5:], {})
                if (not direction.get("blocked", True) and direction.get("walk_endpoint_walkable") is True
                        and tried[(self.region, "escape", action)] < 2):
                    tried[(self.region, "escape", action)] += 1
                    return select(action, "Sondar passagem fisicamente livre apos colisao da rota")
        target = state.get("interaction_target", "")
        if target and fresh("interact"):
            return select("interact", "Exploração: experimentar a interação atual com a ferramenta selecionada")
        for action in sorted(a for a in actions if a.startswith("face_")):
            if fresh(action):
                return select(action, "Exploração: examinar outra interação ao alcance")
        if target and target not in {n.get("name") for n in state.get("npcs", [])} and target != "Pedro" and fresh("work_E"):
            return select("work_E", "Exploração: testar trabalho no alvo próximo")
        for action in ("observe", "inspect_journal", "inspect_inventory", "inspect_map", "inspect_social", "inspect_almanac", "inspect_talents"):
            # Inspeções ficam limitadas à região, independentemente da mão.
            key = (self.region, action)
            if action in actions and tried[key] < 1:
                tried[key] += 1
                return select(action, "Exploração: ler interface para descobrir requisitos e caminhos")
        if target:
            for action in sorted(a for a in actions if a.startswith("hand_")):
                slot = int(action[5:])
                slots = state.get("inventory", {}).get("slots", [])
                if slot >= len(slots):
                    continue
                item = slots[slot].get("id", slots[slot].get("item"))
                key = (self.region, target, item)
                if item != state.get("inventory", {}).get("in_hand") and tried[key] < 1:
                    tried[key] += 1
                    return select(action, "Exploração: experimentar outra ferramenta/item no alvo")
        for action in ("jump", "dodge", "wait"):
            key = (self.region, action)
            if action in actions and tried[key] < 1:
                tried[key] += 1
                return select(action, "Exploração: verificar resposta do controle " + action)
        position = state.get("position", [])
        destinations = []
        if len(position) == 3:
            for npc in state.get("npcs", []):
                destinations.append(("approach_" + npc.get("node", ""), npc.get("position", [])))
            destinations.extend(("explore_" + name, point) for name, point in state.get("world_map", {}).items())
        ranked = []
        for action, point in destinations:
            if action in actions and len(point) == 3:
                distance = sum((point[i] - position[i]) ** 2 for i in (0, 2)) ** 0.5
                ranked.append((self.visited[action], distance, action))
        if ranked:
            # Primeiro os locais próximos ainda não visitados; o raio cresce
            # conforme se esgota a vizinhança, sem escolher destinos aleatórios.
            visits, distance, action = min(ranked)
            self.visited[action] += 1
            return select(action, "Exploração: visitar o próximo alvo acessível (%.1f unidades)" % distance)
        for action in sorted(a for a in actions if a.startswith("walk_")):
            if fresh(action) and state.get("directions", {}).get(action[5:], {}).get("walk_endpoint_walkable") is not False:
                return select(action, "Exploração: sondar passagem livre após esgotar interações")
        return select("wait", "Exploração: aguardar mudança no mundo após esgotar ações disponíveis") or select(next(iter(actions)), "Exploração: ação disponível")

    def choose(self, state, actions, task):
        # Lista de bloqueio do relógio (#192): fora do catálogo antes de qualquer regra.
        actions = {a: d for a, d in actions.items() if not mexe_no_relogio(a, d)}
        if not actions:
            return None
        choice = self._choose(state, actions, task)
        if choice in actions:
            return choice
        # A regra contextual pode pedir algo que a ponte deixou de oferecer.
        # Continuar com uma opção real; nunca encerrar a partida por essa lacuna.
        def permitted(action, reason):
            action, reason = self._leave_room_first(state, actions, action, reason)
            if action not in actions:
                return None
            self.reason = "Acao contextual indisponivel; " + reason
            self.last_action = action
            self.attempts[action] += 1
            self.coverage[(self._context(state), action)] += 1
            time.sleep(self.action_delay if action not in ("wait",) and not action.startswith(("walk_", "approach_", "explore_")) else 0)
            return action
        return self._explore(state, actions, permitted)

    def _choose(self, state, actions, task):
        # Campos novos também aparecem quando a política é recarregada numa
        # sessão antiga, sem descartar sua memória.
        for key, value in {"coverage": Counter(), "visited": Counter(), "screen_probes": 0,
                           "previous_context": None, "progress_signature": None,
                           "last_progress_time": 0.0, "recovery": False, "last_valid_objective": {},
                           "room_position": [], "room_still": 0, "room_exit_tries": 0,
                           "equipping": "", "tool_note": ""}.items():
            self.__dict__.setdefault(key, value)
        self.tool_note = ""
        context = self._context(state)
        self.region = json.dumps([round(v / 12) for v in state.get("position", [])])
        self.route_failed = bool(task.get("last_action_failed")) and self.last_action.startswith(("approach_", "explore_", "gather_", "objective", "follow_pedro"))
        now = float(state.get("seconds", time.monotonic()))
        # Texto/alvo podem mudar sem cumprir uma etapa: conta somente meta,
        # quantidade feita, inventário e obras construídas como progresso.
        obj = state.get("objective", {}) or self.last_valid_objective
        if obj.get("id"):
            self.last_valid_objective = obj.copy()
        signature = json.dumps([obj.get("id"), obj.get("feito"), self._inventory(state),
                                state.get("built_works", {}), state.get("resource_work", {})], sort_keys=True)
        if signature != self.progress_signature:
            self.progress_signature = signature
            self.last_progress_time = now
            self.recovery = False
        elif now - self.last_progress_time >= 30:
            self.recovery = True
        goal = state.get("objective", {}).get("id", task.get("step", {}).get("id", "opening"))
        progress = state.get("objective", {}).get("feito", 0)
        if (goal, progress) != self.last_goal:
            self.attempts.clear()
            self.last_goal = (goal, progress)
        observation = json.dumps({k: state.get(k) for k in
                                  ("position", "objective", "screen", "inventory", "inventory_screen",
                                   "interaction_target", "home_interaction", "resource_work")}, sort_keys=True)
        self.repeated_observations = self.repeated_observations + 1 if observation == self.last_observation else 0
        self.last_observation = observation

        def select(action, reason):
            action, reason = self._leave_room_first(state, actions, action, reason)
            if action in actions:
                marker = (state.get("objective", {}).get("alvo", []) if action == "objective" else
                          state.get("world_map", {}).get(action[8:], []) if action.startswith("explore_") else [])
                if action in ("follow_pedro", GUIDE_APPROACH):
                    marker = next((n.get("position", []) for n in state.get("npcs", [])
                                   if n.get("node") == "MoradorPedro" or n.get("name") == "Pedro"), state.get("pedro", {}).get("position", []))
                position = state.get("position", [])
                if action.startswith("gather_"):
                    marker = state.get("resource_targets", {}).get(action[7:], [])
                if action.startswith("walk_") and self.route_failed and len(position) == 3:
                    counter = ("route_escape", goal)
                    self.attempts[counter] += 1
                    self.escape_leg = {"action": action, "origin": position.copy(), "goal": goal,
                                       "limit": min(24, 8 * self.attempts[counter]),
                                       "target": getattr(self, "navigation_leg", {}).get("target", state.get("objective", {}).get("alvo", []))}
                if len(marker) == len(position) == 3:
                    self.navigation_leg = {"goal": goal, "action": action, "target": marker,
                                           "distance": sum((position[i] - marker[i]) ** 2 for i in (0, 2)) ** 0.5}
                self.reason = (self.tool_note + ": " if self.tool_note else "") + reason
                self.attempts[action] += 1
                self.last_action = action
                self.coverage[(context, action)] += 1
                # Pausa de apresentação: a escolha continua local e determinística,
                # mas o observador pode acompanhar cada operação separadamente.
                work = task.get("step", {}).get("meta", {}).get("eventos", [])
                delay = self.work_delay if action in ("interact", "work_E") and any(
                    e in work for e in ("arou", "plantou", "regou")) else self.action_delay
                if action.startswith(("walk_", "run_", "approach_", "explore_", "gather_")) or action in ("objective", "follow_pedro", "wait"):
                    delay = 0.0
                time.sleep(delay)
                return action
            return None

        if len(actions) == 1 and "wait" in actions:
            return select("wait", "Somente espera disponível: registrar bloqueio dos controles, sem inventar uma ação")

        for action, description in actions.items():
            if description == "Click PULAR":
                return select(action, "Pular introdução e iniciar a campanha")
        if "name_player" in actions:
            return select("name_player", "Preencher o nome visivel da partida de teste e confirmar Enter")
        buttons = [a for a in actions if a.startswith("button_")]
        if buttons:
            return select(buttons[0], "Avançar a abertura em partida nova")
        for action in ("answer_yes", "dialogue_next"):
            if action in actions:
                return select(action, "Responder ou avançar a fala atual")

        # Checkpoint é feito pelo menu normal: Esc, escolher Salvar, E e Esc.
        # O estado observado não é copiado para o save pelo testador.
        materials = sum(self._inventory(state).get(item, 0) for item in ("lenha", "pedra", "tabua", "corda"))
        if not hasattr(self, "checkpoint_time"):
            self.checkpoint_time, self.checkpoint_materials = now - 300, materials
        if getattr(self, "checkpoint_pending", False):
            menu = state.get("pause_menu", {})
            if state.get("screen") != "menu_pausa":
                return select("inspect_pause", "Abrir pausa para salvar o progresso pelo menu normal") or select("close_screen", "Fechar outra tela antes do checkpoint")
            if menu.get("notice"):
                self.checkpoint_notice = menu["notice"]
                self.checkpoint_pending = False
                self.checkpoint_time, self.checkpoint_materials = now, materials
                return select("close_screen", "Registrar a resposta de Salvar e retomar a campanha")
            target = menu.get("save_index", -1)
            cursor = menu.get("cursor", 0)
            if target < 0:
                self.checkpoint_pending = False
                self.checkpoint_time = now
                return select("close_screen", "Menu sem opção de salvar: registrar limitação e continuar")
            if cursor != target:
                return select("screen_down" if cursor < target else "screen_up", "Selecionar Salvar jogo no menu visível")
            return select("confirm_screen", "Confirmar Salvar jogo com E, sem alterar o save diretamente")
        work_in_progress = any(c.get("target", {}).get("em_trabalho") for c in state.get("interaction_candidates", []))
        if not state.get("screen") and not work_in_progress and "inspect_pause" in actions and (now - self.checkpoint_time >= 300 or materials - self.checkpoint_materials >= 8):
            self.checkpoint_pending = True
            return select("inspect_pause", "Guardar checkpoint antes de continuar viagens e lotes de material")

        # Preso num canto do cômodo (#191): a posição quase não muda por três ações de
        # deslocamento seguidas. Força "soleira de dentro -> sair -> recalcular"; se nem a
        # saída resolver em duas tentativas, sonda uma direção livre (e o deslocamento
        # sem efeito da saída já entra no relatório como bloqueio).
        room, here = state.get("room") or {}, state.get("position", [])
        moved = len(here) == len(self.room_position) == 3 and sum((here[i] - self.room_position[i]) ** 2 for i in (0, 2)) ** 0.5 >= 0.5
        travelled = self.last_action.startswith(TRAVEL_ACTIONS) and self.last_action not in STAY_INSIDE_ACTIONS
        self.room_still = self.room_still + 1 if room and travelled and not moved else 0
        if moved or not room:
            self.room_exit_tries = 0
        self.room_position = list(here)
        exit_action = self._room_exit(actions)
        if room and exit_action and not state.get("screen") and self.room_still >= 3:
            if self.room_exit_tries < 2:
                self.room_exit_tries += 1
                return select(exit_action, "Preso num canto do comodo: ir a soleira de dentro, sair e recalcular a rota")
            self.route_failed = True
            self.room_still = 0
            return self._explore(state, actions, select)

        pending_main = [m for m in state.get("journal", {}).get("ativas", []) if m.get("principal")]
        # Uma etapa concluída sai da lista e a próxima entra no fim. A ordem
        # de inserção não deve trocar a cadeia do guia pela missão de outro NPC.
        main_mission = next((m for m in pending_main if m.get("dono") == "pedro"), next(iter(pending_main), {}))
        if state.get("farm", {}).get("awaiting_morning") and not any(m.get("dono") == "pedro" for m in pending_main):
            if state.get("screen"):
                return select("close_screen", "Convite aguarda outra manha: fechar interface antes de dormir")
            if state.get("interior") == "casa":
                if state.get("home_interaction") == "cama":
                    if state.get("interaction_target") == "CasaDoJogador":
                        return select("interact", "Dormir pela cama para chegar ao dia do convite")
                    if "face_CasaDoJogador" in actions:
                        return select("face_CasaDoJogador", "Dar foco ao E da cama para esperar o dia do convite")
                if "approach_bed" in actions:
                    return select("approach_bed", "Convite aguarda outra manha: chegar a cama")
            elif "enter_home" in actions:
                return select("enter_home", "Convite aguarda outra manha: voltar pela porta para dormir")
        next_guide_chain = any(c.get("key") == "pedro" and c.get("main") and not c.get("started") and not c.get("completed") and not c.get("locked", False) for c in state.get("mission_chains", []))
        if not any(m.get("dono") == "pedro" for m in pending_main) and next_guide_chain and not state.get("screen"):
            probe = ("next_guide_chain", tuple(c.get("name") for c in state.get("mission_chains", []) if c.get("completed")))
            if self.attempts[probe] < 3:
                if state.get("interaction_target") in ("Pedro", "MoradorPedro") and "interact" in actions:
                    self.attempts[probe] += 1
                    return select("interact", "Perguntar ao guia pela proxima cadeia liberada da historia")
                walk = self._guide_walk(actions)
                walks = probe + ("walk",)
                if walk and self.attempts[walks] < 6:
                    # Limitado: o guia fora de alcance não prende o testador numa viagem sem fim (#191).
                    self.attempts[walks] += 1
                    return select(walk, "Voltar ao guia para descobrir a proxima cadeia liberada")
        if main_mission and state.get("objective", {}).get("id") != main_mission.get("id"):
            # A sondagem pode mudar o foco: retomar a principal pela seleção
            # visível da caderneta, sem alterar seu estado diretamente.
            if not state.get("screen"):
                return select("inspect_journal", "Retomar pela caderneta a missao principal ainda pendente")
            panel = state.get("panel", {})
            if not panel or 0 not in panel.get("allowed_tabs", [0]):
                return select("close_screen", "Voltar a caderneta para acompanhar a historia principal")
            if panel.get("tab") != 0:
                return select("screen_tab", "Voltar a aba Missoes antes de selecionar a historia principal")
            entries = panel.get("entries", [])
            index = next((i for i, entry in enumerate(entries) if isinstance(entry, dict) and entry.get("id") == main_mission.get("id")), None)
            if index is None:
                return select("close_screen", "A missao principal nao aparece nesta lista; reler a caderneta")
            cursor = int(panel.get("cursor", 0))
            return select("confirm_screen" if cursor == index else "screen_down" if cursor < index else "screen_up",
                          "Acompanhar pela interface a missao principal: " + main_mission.get("id", ""))

        escape = getattr(self, "escape_leg", {})
        if escape and not state.get("screen"):
            position = state.get("position", [])
            direction = state.get("directions", {}).get(escape["action"][5:], {})
            moved = sum((position[i] - escape["origin"][i]) ** 2 for i in (0, 2)) ** 0.5 if len(position) == 3 else 8
            marker = escape.get("target", state.get("objective", {}).get("alvo", []))
            arrived = len(marker) == len(position) == 3 and sum((position[i] - marker[i]) ** 2 for i in (0, 2)) <= 9
            limit = escape.get("limit", 8)
            if limit >= 24 and len(marker) == len(position) == 3:
                # Após regressões repetidas da rota, cada passo físico volta
                # a escolher a direção livre que aproxima do alvo observado.
                directions = state.get("directions", {})
                clear = [a for a in actions if a.startswith("walk_")
                         and not directions.get(a[5:], {}).get("blocked", True)
                         and directions.get(a[5:], {}).get("walk_endpoint_walkable") is True]
                def remaining(a):
                    point = directions[a[5:]].get("walk_endpoint", [])
                    return sum((point[i] - marker[i]) ** 2 for i in (0, 2)) if len(point) == 3 else float("inf")
                if clear:
                    best = min(clear, key=remaining)
                    if remaining(best) < sum((position[i] - marker[i]) ** 2 for i in (0, 2)):
                        escape["action"] = best
                        direction = directions[best[5:]]
            if (escape.get("goal") == goal and moved < limit and not arrived and not task.get("last_action_failed")
                    and escape["action"] in actions and not direction.get("blocked", True)
                    and direction.get("walk_endpoint_walkable") is True):
                return select(escape["action"], "Continuar o contorno livre antes de recalcular a rota que colidiu")
            self.escape_leg = {}
            if moved >= limit or arrived:
                self.recovery = False
                self.last_progress_time = now

        resource_meta = task.get("step", {}).get("meta", {})
        material_budget = Counter(resource_meta.get("itens", {}))
        owned = self._inventory(state)
        for recipes in state.get("crafting", {}).values():
            for recipe in recipes:
                missing = max(0, material_budget.get(recipe.get("id"), 0) - owned.get(recipe.get("id"), 0))
                data = recipe.get("requirements", {})
                produced = max(1, int(data.get("rende", 1)))
                batches = (missing + produced - 1) // produced
                for item, quantity in data.get("custo", {}).items():
                    if item in ("lenha", "pedra"):
                        material_budget[item] += batches * quantity
        resource_item = resource_meta.get("item")
        if not resource_item:
            resource_item = next((item for item, qty in material_budget.items()
                                  if item in ("lenha", "pedra") and self._inventory(state).get(item, 0) < qty), None)
        resource_quantity = material_budget.get(resource_item, resource_meta.get("quantos", state.get("objective", {}).get("total", 1)))
        if any(c.get("target", {}).get("em_trabalho") for c in state.get("interaction_candidates", [])) and "wait" in actions:
            return select("wait", "Esperar o trabalho em andamento concluir antes de executar outro golpe")
        if getattr(self, "food_recovery", False) and state.get("energy", 100) >= 15:
            self.food_recovery = False
            if state.get("inventory_screen"):
                return select("close_screen", "Folego recuperado: fechar mochila e retomar o trabalho")
        if state.get("energy", 100) < 15:
            food_ids = state.get("inventory", {}).get("food_items", [r.get("id") for r in state.get("crafting", {}).get("Cozinha", [])])
            slots = state.get("inventory", {}).get("slots", [])
            food_slot = next((i for i, slot in enumerate(slots) if slot.get("id") in food_ids and slot.get("qtd", 0) > 0), None)
            if food_slot is not None:
                self.food_recovery = True
                if not state.get("screen"):
                    return select("inspect_inventory", "Folego baixo: abrir mochila para comer antes de continuar o trabalho")
                ui = state.get("inventory_screen", {})
                if not ui or ui.get("chest"):
                    return select("close_screen", "Fechar outra interface para acessar a comida da mochila")
                cursor = int(ui.get("cursor", 0))
                if cursor == food_slot:
                    return select("screen_use", "Comer com F a comida selecionada e recuperar folego")
                if cursor >= len(slots):
                    return select("screen_left", "Voltar dos encaixes aos itens da mochila")
                if cursor // 10 != food_slot // 10:
                    return select("screen_down" if cursor // 10 < food_slot // 10 else "screen_up", "Selecionar fileira da comida")
                return select("screen_right" if cursor < food_slot else "screen_left", "Selecionar comida para recuperar folego")
            if state.get("screen"):
                return select("close_screen", "Sem comida: fechar interface antes de buscar descanso")
            if state.get("interior") == "casa":
                if state.get("home_interaction") == "cama":
                    if state.get("interaction_target") == "CasaDoJogador":
                        return select("interact", "Folego baixo e sem comida: pedir descanso na cama pelo E")
                    if "face_CasaDoJogador" in actions:
                        return select("face_CasaDoJogador", "Dar foco ao E da cama antes de descansar")
                if "approach_bed" in actions:
                    return select("approach_bed", "Chegar a cama para recuperar folego sem comida")
            elif "enter_home" in actions:
                return select("enter_home", "Folego baixo e sem comida: voltar pela porta para descansar")
        demanded = self._tool_demanded(state)
        if demanded:
            equip = self._equip_tool(state, actions, select, demanded)
            if equip:
                return equip
        if resource_meta.get("tipo") == "juntar" and resource_item in ("lenha", "pedra") and self._inventory(state).get(resource_item, 0) < resource_quantity:
            hand = state.get("inventory", {})
            required_tool = "picareta" if resource_item == "pedra" else "machado"
            equip = self._equip_tool(state, actions, select, required_tool)
            if equip:
                return equip
            marker = state.get("resource_targets", {}).get(resource_item, state.get("objective", {}).get("alvo", []))
            for candidate in state.get("interaction_candidates", []):
                point = candidate.get("target", {}).get("ponto", [])
                source = candidate.get("source", "")
                if not (source == "Recursos3D" or resource_item == "lenha" and candidate.get("kind") == "tree") or len(point) != 3 or len(marker) != 3:
                    continue
                if sum((point[i] - marker[i]) ** 2 for i in (0, 2)) >= 4:
                    continue
                action = ("work_E" if (resource_item == "pedra" or hand.get("in_hand") == "machado") and "work_E" in actions else "interact") if state.get("interaction_target") == source else "face_" + source
                if action in actions and self.coverage[(context, action)] < 3 and not task.get("last_action_failed"):
                    return select(action, "Priorizar o recurso exigido antes de explorar conversas ou interfaces")
            if (not state.get("screen") and "gather_" + resource_item in actions
                    and not task.get("last_action_failed")):
                action = "gather_" + resource_item
                leg = getattr(self, "navigation_leg", {})
                position = state.get("position", [])
                stalled = (goal, resource_item, "gather_stalled")
                if len(position) == len(marker) == 3:
                    distance = sum((position[i] - marker[i]) ** 2 for i in (0, 2)) ** 0.5
                    if self.last_action == action and leg.get("target") == marker:
                        self.attempts[stalled] = self.attempts[stalled] + 1 if distance >= leg.get("distance", distance) - 0.5 else 0
                    else:
                        self.attempts[stalled] = 0
                    if self.attempts[stalled] >= 2:
                        self.route_failed = True
                        return self._explore(state, actions, select)
                return select("gather_" + resource_item, "Agrupar material direto e custo das receitas antes de viajar a oficina")
        # Repetir a mesma interação sem efeito também abre exploração, mesmo
        # que o relógio ou um NPC tenham mudado de posição.
        meta_now = task.get("step", {}).get("meta", {})
        npc_now = task.get("required_npc", {})
        if (meta_now.get("tipo") in ("falar", "levar") and state.get("interaction_target")
                and state.get("interaction_target") in (npc_now.get("node"), npc_now.get("name"))
                and not npc_now.get("speaking") and "interact" in actions
                and self.coverage[(context, "interact")] < 3):
            return select("interact", "Falar com o destinatario real ao alcance em vez de continuar aproximando")
        if (state.get("pedro", {}).get("conducting") and not state.get("pedro", {}).get("guide_destination_reached")
                and "follow_pedro" in actions and not task.get("last_action_failed")):
            if state.get("interior") == "casa" and "exit_home" in actions:
                return select("exit_home", "Sair pela porta antes de acompanhar o guia no mundo externo")
            return select("follow_pedro", "Concluir a caminhada guiada ativa mesmo com outra missao selecionada na caderneta")
        wanted = meta_now.get("item")
        if not wanted:
            recipe_ids = {r.get("id") for recipes in state.get("crafting", {}).values() for r in recipes}
            wanted = next((item for item, qty in meta_now.get("itens", {}).items() if item in recipe_ids and self._inventory(state).get(item, 0) < qty), None)
        craft_event = str(meta_now.get("evento", ""))
        requires_cooking_event = craft_event.startswith("cozinhou:")
        if requires_cooking_event:
            wanted = craft_event.split(":", 1)[1]
        if state.get("interior") == "casa" and not state.get("screen"):
            outside_goals = {"pedro_roca", "pedro_lenha", "pedro_pedra_do_poco", "pedro_corda", "pedro_poco"}
            if not task.get("step") or state.get("objective", {}).get("id") in outside_goals or any(
                    recipe.get("id") == wanted for recipes in state.get("crafting", {}).values() for recipe in recipes):
                if "exit_home" in actions:
                    return select("exit_home", "Sair pela soleira real antes de buscar o objetivo externo")
        missing_recipe = next(((station, recipe) for station, recipes in state.get("crafting", {}).items()
                               for recipe in recipes if recipe.get("id") == wanted and
                               (requires_cooking_event or self._inventory(state).get(wanted, 0) < meta_now.get("itens", {}).get(wanted, meta_now.get("quantos", 1)))), None)
        if missing_recipe:
            station, recipe = missing_recipe
            anchor = {"Cozinha": "Fogueira"}.get(station, station)
            if not recipe.get("impediment"):
                panel = state.get("panel", {})
                tab = {"Oficina": 3, "Cozinha": 4}.get(station)
                if panel and tab is not None:
                    if panel.get("tab") != tab:
                        probe = (state.get("objective", {}).get("id"), station, "tab_probe")
                        allowed = panel.get("allowed_tabs")
                        if (allowed is not None and tab not in allowed) or self.attempts[probe] >= 8:
                            self.attempts[probe] = 0
                            return select("close_screen", "A receita nao esta nesta interface; fechar e reaproximar a bancada")
                        self.attempts[probe] += 1
                        return select("screen_tab", "Procurar a aba da receita necessaria")
                    recipes = state.get("crafting", {}).get(station, [])
                    index = next(i for i, r in enumerate(recipes) if r.get("id") == wanted)
                    cursor = int(panel.get("cursor", 0))
                    if cursor == index:
                        return select("confirm_screen", "Fabricar o material exigido: " + wanted)
                    return select("screen_down" if cursor < index else "screen_up", "Selecionar a receita exigida")
                if not state.get("screen"):
                    pos = state.get("position", [])
                    point = state.get("world_map", {}).get(anchor, [])
                    if len(pos) == len(point) == 3 and sum((pos[i] - point[i]) ** 2 for i in (0, 2)) <= 9:
                        return select("inspect_journal", "Abrir as receitas ao alcance da bancada")
                    if "explore_" + anchor in actions and self.coverage[(context, "explore_" + anchor)] < 2:
                        return select("explore_" + anchor, "Ir diretamente à bancada que produz " + wanted)
        required_npc = task.get("required_npc", {})
        if required_npc.get("speaking") and required_npc.get("distance", 999) < 4 and not state.get("pedro", {}).get("conducting"):
            return select("wait", "Aguardar a fala atual terminar antes de iniciar outra conversa")
        if not task.get("step") and not state.get("screen"):
            pedro = state.get("pedro", {})
            if pedro.get("speaking") and pedro.get("distance", 999) < 4:
                return select("wait", "Ouvir o guia antes de pedir o proximo trabalho")
            if state.get("interaction_target") in ("MoradorPedro", "Pedro") and self.coverage[(context, "interact")] < 2:
                return select("interact", "Pedir ao guia a proxima cadeia depois de terminar a anterior")
            walk = self._guide_walk(actions)
            if walk and self.coverage[(context, walk)] < 2:
                return select(walk, "Procurar o guia para iniciar a proxima cadeia da historia")
        work_meta = task.get("step", {}).get("meta", {})
        if work_meta.get("tipo") == "obra" and state.get("panel"):
            panel = state["panel"]
            if 2 not in panel.get("allowed_tabs", []):
                return select("close_screen", "As obras nao estao disponiveis nesta posicao")
            if panel.get("tab") != 2:
                return select("screen_tab", "Abrir a aba de obras disponivel neste local")
            entries = panel.get("entries", [])
            wanted_work = work_meta.get("obra")
            if panel.get("construction") != work_meta.get("construcao") or wanted_work not in entries:
                return select("close_screen", "A obra exigida nao aparece nesta lista; nao executar outra obra ao acaso")
            index = entries.index(wanted_work)
            cursor = int(panel.get("cursor", 0))
            if cursor == index:
                return select("confirm_screen", "Executar pela interface a obra exigida: " + wanted_work)
            return select("screen_down" if cursor < index else "screen_up", "Selecionar a obra exigida")
        if task.get("step", {}).get("meta", {}).get("tipo") == "obra" and not state.get("screen"):
            marker = state.get("objective", {}).get("alvo", [])
            position = state.get("position", [])
            if len(marker) == len(position) == 3 and not task.get("last_action_failed"):
                distance = sum((position[i] - marker[i]) ** 2 for i in (0, 2)) ** 0.5
                if distance > min(3, float(task.get("step", {}).get("raio", 3))):
                    leg = getattr(self, "navigation_leg", {})
                    counter = (goal, "work_route_stalled")
                    if leg.get("goal") == goal and self.last_action == "objective":
                        self.attempts[counter] = self.attempts[counter] + 1 if distance >= leg.get("distance", distance) - 0.5 else 0
                    if self.attempts[counter] < 3:
                        return select("objective", "Viajar ate a obra antes de sondar interfaces fora do seu alcance")
                else:
                    return select("inspect_journal", "Inspecionar as obras depois de chegar ao local certo")
        leg = getattr(self, "navigation_leg", {})
        position = state.get("position", [])
        marker = leg.get("target", [])
        if (not state.get("screen") and leg.get("goal") == goal and self.last_action == leg.get("action")
                and not task.get("last_action_failed") and len(position) == len(marker) == 3):
            distance = sum((position[i] - marker[i]) ** 2 for i in (0, 2)) ** 0.5
            if 3 < distance < leg["distance"] - 0.5:
                return select(leg["action"], "Continuar a rota que aproxima do alvo; viagem longa ainda nao e bloqueio")
        direct_now = [a for a in task.get("actions_matching_the_current_requirement", [])
                      if a in actions and a not in task.get("last_action_failed", [])]
        if direct_now and self.coverage[(context, direct_now[0])] < 3:
            return select(direct_now[0], "Cumprir a exigencia disponivel antes de explorar alternativas")
        if (self.recovery and not state.get("interaction_target") == "Recursos3D") or (self.last_action in ("interact", "work_E", "objective") and
                             self.coverage[(context, self.last_action)] >= 3):
            self.recovery = True
            # As telas com requisitos conhecidos ainda usam a regra contextual.
            if not state.get("screen"):
                return self._explore(state, actions, select)

        if self.repeated_observations >= 6:
            self.repeated_observations = 0
            if state.get("screen"):
                return select("close_screen", "Reabrir a interface após ações sem mudança observável")
            if self.last_action.startswith("approach_") and "interact" in actions:
                return select("interact", "Já chegou ao alvo: tentar a interação em vez de aproximar novamente")
            self.recovery = True
            return self._explore(state, actions, select)

        step = task.get("step", {})
        meta = step.get("meta", {})
        inv = state.get("inventory", {})
        slots = inv.get("slots", [])
        items = Counter()
        for slot in slots:
            item = slot.get("id", slot.get("item", ""))
            if item:
                items[item] += int(slot.get("qtd", slot.get("quantidade", slot.get("q", 1))))

        if state.get("screen"):
            ui = state.get("inventory_screen", {})
            chest = ui.get("chest", [])
            read_event = str(meta.get("evento", ""))
            if ui and read_event.startswith("leu:"):
                document = read_event.split(":", 1)[1]
                index = next((i for i, slot in enumerate(slots) if slot.get("id") == document), None)
                if index is not None:
                    cursor = int(ui.get("cursor", 0))
                    if cursor == index:
                        return select("screen_use", "Ler com F o documento exigido pela missao")
                    if cursor >= len(slots):
                        return select("screen_left", "Voltar dos encaixes para a mochila")
                    if cursor // 10 != index // 10:
                        return select("screen_down" if cursor // 10 < index // 10 else "screen_up", "Chegar a fileira do documento")
                    return select("screen_right" if cursor < index else "screen_left", "Selecionar o documento exigido")
            needed = meta.get("itens", {})
            missing = [item for item, qty in needed.items() if items[item] < qty]
            if chest and missing:
                cursor = int(ui.get("cursor", 0))
                # The chest starts after inventory and equipment slots. Navigate
                # through real keys, using its actual selected item in observations.
                for item in missing:
                    for index, slot in enumerate(chest):
                        if slot.get("id", slot.get("item")) == item:
                            base = int(ui.get("chest_cursor_base", 35))
                            target = base + index
                            if cursor == target:
                                return select("confirm_screen", "Retirar do baú o item necessário")
                            if cursor < base:
                                if cursor >= len(slots):
                                    return select("screen_left", "Voltar dos encaixes para a mochila")
                                return select("screen_up", "Subir da mochila para o baú")
                            # O baú é uma grade independente: seus índices globais
                            # não têm as mesmas fileiras da mochila.
                            return select("screen_right" if cursor < target else "screen_left", "Selecionar item do baú")
            if self.recovery:
                return self._explore(state, actions, select)
            return select("close_screen", "Fechar tela e continuar o objetivo")

        history = state.get("recent_actions", [])
        # Metas de recurso usam item/quantos; não são a lista de ferramentas
        # do baú (itens). O marcador vivo aponta o galho que pode ser coletado.
        resource_item = meta.get("item")
        if meta.get("tipo") == "juntar" and resource_item in ("lenha", "pedra") and items[resource_item] < meta.get("quantos", state.get("objective", {}).get("total", 1)):
            tool = "picareta" if resource_item == "pedra" else ("machado" if self._tool_places(state, "machado") != (-1, -1) else None)
            equip = self._equip_tool(state, actions, select, tool)
            if equip:
                return equip
            resource = next((c for c in state.get("interaction_candidates", [])
                             if c.get("source") == "Recursos3D"), {})
            point = resource.get("target", {}).get("ponto", [])
            marker = state.get("objective", {}).get("alvo", [])
            matches = len(point) == len(marker) == 3 and sum((point[i] - marker[i]) ** 2 for i in (0, 2)) < 4
            dry_branch = resource_item == "lenha" and any("Galho seco" in str(o.get("text", ""))
                             for o in state.get("observations", []))
            if resource and (matches or dry_branch):
                if state.get("interaction_target") == "Recursos3D":
                    return select("work_E" if tool and "work_E" in actions else "interact", "Coletar o recurso da missão: " + resource_item)
                if "face_Recursos3D" in actions:
                    return select("face_Recursos3D", "Priorizar o recurso indicado em vez da conversa com Pedro")
            if task.get("last_action_failed"):
                choices = [a for a in actions if a.startswith("walk_") and a not in task.get("last_action_failed", []) and
                           not state.get("directions", {}).get(a[5:], {}).get("blocked", False) and
                           state.get("directions", {}).get(a[5:], {}).get("walk_endpoint_walkable") is not False]
                if choices:
                    return select(min(choices, key=lambda a: self.attempts[a]), "Contornar o obstáculo até o galho seco")
            return select("objective", "Seguir o marcador do recurso até alcançar sua interação")
        if task.get("last_action_failed"):
            choices = [a for a in actions if a.startswith("walk_") and a not in task.get("last_action_failed", []) and
                           not state.get("directions", {}).get(a[5:], {}).get("blocked", False) and
                       state.get("directions", {}).get(a[5:], {}).get("walk_endpoint_walkable") is not False]
            if choices:
                marker = state.get("objective", {}).get("alvo", [])
                def toward_goal(action):
                    point = state.get("directions", {}).get(action[5:], {}).get("walk_endpoint", [])
                    distance = sum((point[i] - marker[i]) ** 2 for i in (0, 2)) if len(point) == len(marker) == 3 else float("inf")
                    return (distance, self.attempts[action], action)
                action = min(choices, key=toward_goal)
                return select(action, "Sair do bloqueio por outra direção")
        direct = task.get("actions_matching_the_current_requirement", [])
        if direct:
            return select(next((a for a in direct if a in actions), "" ), "Cumprir a exigência atual da missão")

        events = meta.get("eventos", [meta.get("evento", "")])
        event = events[min(int(progress), len(events) - 1)] if events else ""
        target = state.get("interaction_target", "")
        guide = state.get("pedro", {})
        if step.get("conduz") and guide.get("conducting") and not guide.get("guide_destination_reached"):
            return select("follow_pedro", "Acompanhar o guia antes de realizar a ação")
        if event == "abriu_painel":
            return select("inspect_journal", "Abrir a caderneta solicitada")
        tool = {"arou": "enxada", "plantou": "semente_mandioca", "regou": "balde"}.get(event)
        if tool:
            if inv.get("in_hand") != tool:
                for index, slot in enumerate(slots[:10]):
                    if slot.get("id", slot.get("item")) == tool:
                        return select(f"hand_{index}", "Selecionar a ferramenta do próximo passo: " + tool)
            if "Lavoura" in target or "lavoura" in target.lower():
                return select("interact", "Realizar o próximo trabalho na leira: " + event)
            if "face_Lavoura" in actions:
                return select("face_Lavoura", "Orientar o corpo para a leira")
            return select("explore_Lavoura", "Chegar à lavoura para trabalhar") or select("objective", "Chegar ao ponto da missão")
        if (meta.get("tipo") == "juntar" and step.get("lugar") == "casa_de_taipa"
                and any(items[k] < v for k, v in meta.get("itens", {}).items())):
            if state.get("interior") == "casa":
                if state.get("home_interaction") == "bau" and target != "CasaDoJogador" and "face_CasaDoJogador" in actions:
                    return select("face_CasaDoJogador", "Orientar a interacao para o bau em vez de conversar com outro personagem")
                if state.get("home_interaction") == "bau" or "Baú" in str(actions.get("interact", "")) or "Bau" in target or ("home_interaction" not in state and target == "CasaDoJogador"):
                    return select("interact", "Abrir o baú pelas teclas normais")
                if self.attempts["approach_chest"] >= 3:
                    if "face_CasaDoJogador" in actions:
                        return select("face_CasaDoJogador", "Reorientar para a interação da casa")
                    return select("observe", "Reavaliar o baú após aproximações sem resultado")
                return select("approach_chest", "Buscar as ferramentas no baú")
            return select("enter_home", "Entrar pela porta para alcançar o baú") or select("explore_Casa de taipa", "Chegar à casa")
        if event == "entrou_casa" or step.get("id") == "casa":
            return select("enter_home", "Entrar pela porta da casa") or select("objective", "Chegar à entrada")
        if event == "dormiu":
            if "Dormir" in str(actions.get("interact", "")):
                return select("interact", "Dormir para avançar ao dia seguinte")
            return select("approach_bed", "Chegar à cama") or select("enter_home", "Entrar na casa para descansar")
        if event.startswith("leu:"):
            return select("inspect_inventory", "Procurar o documento na mochila")
        if meta.get("tipo") == "obra":
            if state.get("panel"):
                return select("confirm_screen", "Confirmar a obra disponível")
            return select("objective", "Chegar ao local da construção") or select("inspect_journal", "Inspecionar a obra")
        if target and self.coverage[(context, "interact")] < 1:
            return select("interact", "Experimentar a interação atual e observar o resultado")
        if "objective" in actions and self.attempts["objective"] < 4:
            return select("objective", "Chegar ao objetivo atual")
        return self._explore(state, actions, select)
