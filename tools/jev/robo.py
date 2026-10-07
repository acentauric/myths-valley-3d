"""Local state-based player. Explicit rules, no model API and no hidden progress."""
from collections import Counter
import json
import time


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
                           "goal": state.get("objective", {}).get("id"),
                           "target": state.get("interaction_target"),
                           "hand": state.get("inventory", {}).get("in_hand"),
                           "items": self._inventory(state), "screen": state.get("screen"),
                           "panel": state.get("panel", {}), "ui": state.get("inventory_screen", {})},
                          sort_keys=True)

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
        target = state.get("interaction_target", "")
        if target and fresh("interact"):
            return select("interact", "Exploração: experimentar a interação atual com a ferramenta selecionada")
        for action in sorted(a for a in actions if a.startswith("face_")):
            if fresh(action):
                return select(action, "Exploração: examinar outra interação ao alcance")
        if target and target not in {n.get("name") for n in state.get("npcs", [])} and target != "Pedro" and fresh("work_E"):
            return select("work_E", "Exploração: testar trabalho no alvo próximo")
        for action in ("observe", "inspect_journal", "inspect_inventory", "inspect_map", "inspect_social", "inspect_almanac", "inspect_talents", "inspect_time"):
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
        # Campos novos também aparecem quando a política é recarregada numa
        # sessão antiga, sem descartar sua memória.
        for key, value in {"coverage": Counter(), "visited": Counter(), "screen_probes": 0,
                           "previous_context": None, "progress_signature": None,
                           "last_progress_time": 0.0, "recovery": False}.items():
            self.__dict__.setdefault(key, value)
        context = self._context(state)
        self.region = json.dumps([round(v / 12) for v in state.get("position", [])])
        now = float(state.get("seconds", time.monotonic()))
        # Texto/alvo podem mudar sem cumprir uma etapa: conta somente meta,
        # quantidade feita, inventário e obras construídas como progresso.
        obj = state.get("objective", {})
        signature = json.dumps([obj.get("id"), obj.get("feito"), self._inventory(state),
                                state.get("built_works", {})], sort_keys=True)
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
                                   "interaction_target", "home_interaction")}, sort_keys=True)
        self.repeated_observations = self.repeated_observations + 1 if observation == self.last_observation else 0
        self.last_observation = observation

        def select(action, reason):
            if action in actions:
                self.reason = reason
                self.attempts[action] += 1
                self.last_action = action
                self.coverage[(context, action)] += 1
                # Pausa de apresentação: a escolha continua local e determinística,
                # mas o observador pode acompanhar cada operação separadamente.
                work = task.get("step", {}).get("meta", {}).get("eventos", [])
                delay = self.work_delay if action in ("interact", "work_E") and any(
                    e in work for e in ("arou", "plantou", "regou")) else self.action_delay
                if action.startswith(("walk_", "run_", "approach_", "explore_")) or action in ("objective", "follow_pedro", "wait"):
                    delay = 0.0
                time.sleep(delay)
                return action
            return None

        if len(actions) == 1 and "wait" in actions:
            return select("wait", "Somente espera disponível: registrar bloqueio dos controles, sem inventar uma ação")

        for action, description in actions.items():
            if description == "Click PULAR":
                return select(action, "Pular introdução e iniciar a campanha")
        buttons = [a for a in actions if a.startswith("button_")]
        if buttons:
            return select(buttons[0], "Avançar a abertura em partida nova")
        for action in ("answer_yes", "dialogue_next"):
            if action in actions:
                return select(action, "Responder ou avançar a fala atual")

        # Repetir a mesma interação sem efeito também abre exploração, mesmo
        # que o relógio ou um NPC tenham mudado de posição.
        meta_now = task.get("step", {}).get("meta", {})
        wanted = meta_now.get("item")
        missing_recipe = next(((station, recipe) for station, recipes in state.get("crafting", {}).items()
                               for recipe in recipes if recipe.get("id") == wanted and
                               self._inventory(state).get(wanted, 0) < meta_now.get("quantos", 1)), None)
        if missing_recipe:
            station, recipe = missing_recipe
            if not recipe.get("impediment"):
                panel = state.get("panel", {})
                tab = {"Oficina": 3, "Cozinha": 4}.get(station)
                if panel and tab is not None:
                    if panel.get("tab") != tab:
                        return select("screen_tab", "Procurar a aba da receita necessária")
                    recipes = state.get("crafting", {}).get(station, [])
                    index = next(i for i, r in enumerate(recipes) if r.get("id") == wanted)
                    cursor = int(panel.get("cursor", 0))
                    if cursor == index:
                        return select("confirm_screen", "Fabricar o material exigido: " + wanted)
                    return select("screen_down" if cursor < index else "screen_up", "Selecionar a receita exigida")
                if not state.get("screen"):
                    pos = state.get("position", [])
                    point = state.get("world_map", {}).get(station, [])
                    if len(pos) == len(point) == 3 and sum((pos[i] - point[i]) ** 2 for i in (0, 2)) <= 9:
                        return select("inspect_journal", "Abrir as receitas ao alcance da bancada")
                    if "explore_" + station in actions and self.coverage[(context, "explore_" + station)] < 2:
                        return select("explore_" + station, "Ir diretamente à bancada que produz " + wanted)
        if self.recovery or (self.last_action in ("interact", "work_E", "objective") and
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
        if meta.get("tipo") == "juntar" and resource_item in ("lenha", "pedra") and items[resource_item] < meta.get("quantos", 1):
            tool = "picareta" if resource_item == "pedra" else None
            if tool and inv.get("in_hand") != tool:
                for index, slot in enumerate(slots[:10]):
                    if slot.get("id", slot.get("item")) == tool:
                        return select(f"hand_{index}", "Equipar a picareta antes de aproximar da pedra")
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
                choices = [a for a in actions if a.startswith("walk_") and
                           state.get("directions", {}).get(a[5:], {}).get("walk_endpoint_walkable") is not False]
                if choices:
                    return select(min(choices, key=lambda a: self.attempts[a]), "Contornar o obstáculo até o galho seco")
            return select("objective", "Seguir o marcador do recurso até alcançar sua interação")
        if task.get("last_action_failed"):
            choices = [a for a in actions if a.startswith("walk_") and
                       state.get("directions", {}).get(a[5:], {}).get("walk_endpoint_walkable") is not False]
            if choices:
                action = min(choices, key=lambda a: self.attempts[a])
                return select(action, "Sair do bloqueio por outra direção")
        direct = task.get("actions_matching_the_current_requirement", [])
        if direct:
            return select(direct[0], "Cumprir a exigência atual da missão")

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
        if meta.get("tipo") == "juntar" and any(items[k] < v for k, v in meta.get("itens", {}).items()):
            if state.get("interior") == "casa":
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
