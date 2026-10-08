"""Produce an auditable Markdown playtest report from the session JSONL."""
import argparse
from collections import Counter
import ctypes
import json
import math
import os
from pathlib import Path
import tempfile
import time


ESCADA_EVENTOS = {"escalation": "escalations", "escalation_result": "results", "escalation_denied": "denied",
                  "stuck_signal": "signals", "local_recovery": "locals", "blocked_step": "blocked",
                  "learned_pattern": "learned", "progress": "progress"}
NIVEIS = {"deterministic": "Determinístico", "jev": "Jev", "gpt": "GPT"}
SINAIS = {"sem_progresso_acoes": "ações sem progresso", "sem_progresso_tempo": "tempo sem progresso",
          "laco_de_posicao": "laço de posição", "recusa_repetida": "recusa repetida",
          "alvo_do_e_diferente": "E mirando outro alvo", "possivel_travamento": "possível travamento"}


def cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


CLOCK_REASONS = {
    "pausado": "o relógio está pausado (Dia.pausado) sem tela aberta",
    "velocidade_zero": "a velocidade do relógio está em Parada",
    "segurado": "o relógio está seguro por um motivo há muito tempo",
    "hora_parada": "a hora não andou, sem pausa nem motivo",
}


def clock_stop_line(stop):
    """Uma linha do relatório para um relógio parado: a causa, a última ação e a captura."""
    reason = str(stop.get("reason", "?"))
    held = ", ".join(str(x) for x in stop.get("held_by", [])) or "—"
    capture = str(stop.get("capture", ""))
    link = f" [{capture}]({capture})" if capture else ""
    return (f"- {float(stop.get('elapsed', 0)):.1f} s — relógio parado às {cell(stop.get('time', '?'))}: "
            f"{cell(CLOCK_REASONS.get(reason, reason))} (motivo: {cell(reason)}; segurado por: {cell(held)}; "
            f"velocidade: {cell(stop.get('speed', '?'))}). Última ação: {cell(stop.get('action', '?'))}.{link}")


def manual_effect(before, after):
    """O que o humano mudou durante o controle manual (F7): missão, itens, mão e deslocamento."""
    old, new = before.get("objective", {}) or {}, after.get("objective", {}) or {}
    def progress(goal):
        return f"{goal.get('id', '—')} {goal.get('feito', 0)}/{goal.get('total', 0)}" if goal.get("id") else "—"
    mission = ("missão sem avanço (" + progress(new) + ")" if (old.get("id"), old.get("feito")) == (new.get("id"), new.get("feito"))
               else "missão " + progress(old) + " → " + progress(new))
    gained, lost = inventory(after) - inventory(before), inventory(before) - inventory(after)
    items = ", ".join([f"+{n} {item}" for item, n in sorted(gained.items())] + [f"−{n} {item}" for item, n in sorted(lost.items())]) or "itens iguais"
    hand_old, hand_new = before.get("inventory", {}).get("in_hand") or "mão livre", after.get("inventory", {}).get("in_hand") or "mão livre"
    hand = "mão: " + (hand_old if hand_old == hand_new else f"{hand_old} → {hand_new}")
    return f"{mission}; {items}; {hand}; deslocou {distance(before, after):.1f} unidades"


def manual_line(start, end):
    """Uma linha do relatório por trecho de controle manual: quando, quanto tempo, o que mudou."""
    at = float(start.get("elapsed", 0)) if start else float(end.get("elapsed", 0)) - float(end.get("duration_s", 0))
    last = cell(start.get("last_action", "?")) if start else "?"
    captures = " ".join(f"[{name}]({name})" for name in (end.get("start_capture") or "", end.get("capture") or "") if name) if end else ""
    if end is None:
        return f"- {at:.1f} s — o humano assumiu o controle (F7) e ainda está jogando. Última ação do testador: {last}."
    reason = " (a sessão acabou durante o controle manual)" if end.get("reason") == "session_end" else ""
    return (f"- {at:.1f} s — o humano assumiu o controle (F7) por {float(end.get('duration_s', 0)):.1f} s{reason}. "
            f"Efeito: {cell(manual_effect(end.get('before', {}), end.get('after', {})))}. "
            f"Última ação do testador antes: {last}. {captures}".rstrip())


def hidden_line(hidden):
    """Uma linha do relatório por vez que a câmera não achou lado livre: quanto tempo e a captura."""
    capture = str(hidden.get("capture", ""))
    link = f" [{capture}]({capture})" if capture else ""
    position = ", ".join(f"{float(v):.1f}" for v in hidden.get("position", [])) or "—"
    return (f"- {float(hidden.get('elapsed', 0)):.1f} s — o viajante ficou encoberto por {float(hidden.get('duration_s', 0)):.1f} s "
            f"em {position}. Última ação: {cell(hidden.get('action', '?'))}.{link}")


def distance(before, after):
    a, b = before.get("position", []), after.get("position", [])
    return math.dist(a, b) if len(a) == len(b) == 3 else 0.0


def inventory(state):
    result = Counter()
    for slot in state.get("inventory", {}).get("slots", []):
        if slot.get("id"):
            result[slot["id"]] += int(slot.get("qtd", 1))
    return result


def generate(directory, live=True):
    directory = Path(directory)
    source = directory / "eventos.jsonl"
    counts, durations, steps = Counter(), Counter(), {}
    rows, issues, movement = [], [], 0.0
    clock_stops = []
    manual_stretches, manual_open = [], None
    hidden_traveller = []
    language = ""
    scenario = ""
    sampled_movement, presentation_seconds = 0.0, 0.0
    stalled, stall_start, stall_goal, stall_count = [], None, "", 0
    previous_decision = None
    last_objective = {}
    elapsed = 0.0
    complete = False
    stop = "em andamento" if live else "encerrado (consulte resumo.json)"
    start = None
    escada = {"escalations": [], "results": [], "denied": [], "signals": [], "locals": [], "blocked": None,
              "learned": [], "progress": []}
    # Stream: don't retain repeated full world observations in memory.
    with source.open(encoding="utf-8") as stream:
        for line in stream:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue  # Last line may still be being written.
            elapsed = max(elapsed, float(event.get("elapsed", 0)))
            kind = event.get("kind")
            if kind == "game_ready":
                start = event.get("elapsed", 0)
            if kind == "session_scenario":
                scenario = str(event.get("name", ""))
            if kind == "session_language":
                language = str(event.get("label", ""))
            if kind == "achado" and event.get("type") == "relogio_parado":
                clock_stops.append(event)
            if kind == "achado" and event.get("type") == "viajante_encoberto":
                hidden_traveller.append(event)
            if kind == "manual_control":
                if event.get("phase") == "start":
                    manual_open = event
                else:
                    manual_stretches.append((manual_open, event))
                    manual_open = None
            if kind == "decision":
                previous_decision = event
                presentation_seconds += max(0, float(event.get("latency_ms", 0))) / 1000
            if kind in ESCADA_EVENTOS:
                chave = ESCADA_EVENTOS[kind]
                if chave == "blocked":
                    escada["blocked"] = event
                else:
                    escada[chave].append(event)
            if kind != "outcome":
                continue
            before, after = event.get("before", {}), event.get("after", {})
            action = event.get("action", "?")
            valid_decision = previous_decision and previous_decision.get("choice") == action
            duration = max(0, event.get("elapsed", 0) - previous_decision.get("elapsed", 0)) if valid_decision else None
            counts[action] += 1
            if duration is not None:
                durations[action] += duration
            moved = distance(before, after)
            movement += moved
            samples = event.get("movement_samples", [])
            sampled_movement += sum(distance(a, b) for a, b in zip(samples, samples[1:]))
            old = before.get("objective", {}) or last_objective
            new = after.get("objective", {})
            progressed = bool(old.get("id") and new.get("id")) and (old.get("id"), old.get("feito")) != (new.get("id"), new.get("feito"))
            if new.get("id"):
                last_objective = new
            changed_items = inventory(before) != inventory(after)
            goal = old.get("id", new.get("id", "abertura"))
            entry = steps.setdefault(goal, {"start": event.get("elapsed", 0), "end": 0, "actions": 0, "progress": 0})
            entry["end"] = event.get("elapsed", 0)
            entry["actions"] += 1
            entry["progress"] += int(progressed)
            result = event.get("result", "")
            if progressed or changed_items or before.get("built_works", {}) != after.get("built_works", {}):
                if stall_start is not None and event.get("elapsed", 0) - stall_start >= 30:
                    stalled.append((stall_goal, stall_start, event.get("elapsed", 0), stall_count))
                stall_start, stall_count = None, 0
            else:
                if stall_start is None:
                    stall_start, stall_goal = event.get("elapsed", 0), goal
                stall_count += 1
            rationale = previous_decision.get("rationale", "") if valid_decision else ""
            effect = "missão avançou" if progressed else ("inventário mudou" if changed_items else "sem avanço de missão")
            if any(word in result for word in ("stuck", "blocked", "failed", "no_navigation", "no_walkable")):
                issues.append((event.get("elapsed", 0), goal, action, result))
            complete |= bool(after.get("implemented_story_completed"))
            pos = lambda state: ", ".join(f"{float(v):.1f}" for v in state.get("position", [])) or "—"
            rows.append(f"| {event.get('elapsed', 0):.1f} | {cell(action)} | {duration:.2f} | {pos(before)} → {pos(after)} | {moved:.2f} | {cell(goal)} | {effect}: {cell(result)} | {cell(rationale)} |" if duration is not None else
                        f"| {event.get('elapsed', 0):.1f} | {cell(action)} | — | {pos(before)} → {pos(after)} | {moved:.2f} | {cell(goal)} | {effect}: {cell(result)} | {cell(rationale)} |")
    summary_path = directory / "resumo.json"
    if summary_path.exists():
        try:
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            summary = {}  # The bridge may be writing its final summary.
        stop = summary.get("stop", stop)
        complete |= summary.get("implemented_story_completed", False)
    lines = ["# Relatório do testador automático", "",
             f"Estado: **{cell(stop)}**. História implementada concluída: **{'sim' if complete else 'não demonstrado'}**.", "",
             f"Tempo registrado: {elapsed:.1f} s; desde o jogo pronto: {max(0, elapsed - start):.1f} s." if start is not None else f"Tempo registrado: {elapsed:.1f} s; carregamento sem marcador de início.",
             f"Ações: {sum(counts.values())}. Deslocamento acumulado entre observações: {movement:.2f} unidades.", "",
             *([f"Idioma da sessão: **{cell(language)}**.", ""] if language else []),
             *([f"Cenário de verificação: **{cell(scenario)}** (a partida abriu no meio do caso; não é a campanha inteira).", ""] if scenario else []),
             f"Trajeto amostrado durante movimentos: {sampled_movement:.2f} unidades; tempo de decisão/apresentação: {presentation_seconds:.2f} s.", "",
             "O trajeto amostrado soma segmentos a cada meio segundo, incluindo desvios e retornos; não mede cada frame. "
             "O deslocamento soma distâncias entre início e fim das ações; não mede cada curva do trajeto. "
             "Tempos de ação vêm dos timestamps da decisão e do resultado, sem incluir a espera anterior da política. "
             "Execução de tecla, alteração de inventário e avanço de missão são resultados diferentes.", "",
             "## Etapas observadas", "", "| Etapa | Primeiro/último resultado (s) | Ações | Avanços |", "|---|---:|---:|---:|"]
    for goal, data in steps.items():
        lines.append(f"| {cell(goal)} | {data['start']:.1f} / {data['end']:.1f} | {data['actions']} | {data['progress']} |")
    lines += ["", "## Frequência e duração das ações", "", "| Ação | Quantidade | Tempo acumulado (s) |", "|---|---:|---:|"]
    for action, count in counts.most_common():
        lines.append(f"| {cell(action)} | {count} | {durations[action]:.2f} |")
    lines += ["", "## Bloqueios reportados pelo controlador", ""]
    lines += [f"- {at:.1f} s — {cell(goal)} / {cell(action)}: {cell(result)}" for at, goal, action, result in issues] or ["Nenhum bloqueio explícito registrado. Isso não prova ausência de problemas."]
    lines += ["", "## Relógio parado", ""]
    lines += [clock_stop_line(stop) for stop in clock_stops] or [
        "Nenhum relógio parado sem tela, fala ou motivo à vista. O testador não pausa nem acelera o relógio."]
    if manual_open is not None:
        manual_stretches.append((manual_open, None))
    lines += ["", "## Viajante encoberto pela câmera", ""]
    lines += [hidden_line(hidden) for hidden in hidden_traveller] or [
        "O viajante não ficou encoberto por mais de 1,5 s. A câmera da sessão desvia de poste, tronco, parede e árvore, e só se captura com ele à vista."]
    lines += ["", "## Controle manual (F7)", ""]
    lines += [manual_line(begin, end) for begin, end in manual_stretches] or [
        "Nenhuma vez o humano assumiu o controle. Cada trecho de F7 vira exemplo para ensinar o determinístico ou para a escada da #183: aqui o testador precisou de ajuda."]
    if stall_start is not None and elapsed - stall_start >= 30:
        stalled.append((stall_goal, stall_start, elapsed, stall_count))
    lines += ["", "## Períodos sem progresso de missão, inventário ou obra", ""]
    lines += [f"- {cell(goal)}: {end - begin:.1f} s ({begin:.1f}–{end:.1f}), {count} ações sem mudança significativa."
              for goal, begin, end, count in stalled] or ["Nenhum intervalo registrado de pelo menos 30 segundos."]
    lines += escada_linhas(escada, summary_path)
    lines += ["", "## Evidências e análise contínua", "",
              "Analise etapas com muitas ações e poucos avanços, alternância repetida de movimentos e interações sem efeito. "
              "Cruze esses indícios com os frames e o JSONL antes de atribuir a causa ao jogo ou à política.", "",
              "[Eventos completos](eventos.jsonl) · [Saída do Godot](stdout.log) · [Erros do Godot](stderr.log)", ""]
    screenshots = [*directory.glob("quadro_*.png"), *directory.glob("quadro_*.jpg")]
    for screenshot in sorted(screenshots):
        lines.append(f"- [Captura {screenshot.stem}]({screenshot.name})")
    lines += ["", "## Linha do tempo de movimentos e decisões", "",
              "| Instante (s) | Ação | Duração (s) | Posição inicial → final | Distância | Objetivo | Resultado observado | Motivo da escolha |",
              "|---:|---|---:|---|---:|---|---|---|"] + rows
    output = directory / "relatorio.md"
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=directory,
                                     prefix="relatorio-", suffix=".tmp", delete=False) as stream:
        stream.write("\n".join(lines) + "\n")
        temporary = Path(stream.name)
    try:
        temporary.replace(output)
    finally:
        temporary.unlink(missing_ok=True)
    return output


def segundos_texto(valor):
    if valor is None:
        return "—"
    valor = int(valor)
    return f"{valor // 60} min {valor % 60:02d} s" if valor >= 60 else f"{valor} s"


def resultado_do_escalonamento(evento, resultados):
    """Texto da última coluna: destravou, falhou ou o motivo de não ter plano."""
    if not evento.get("plano"):
        return "sem plano: " + cell(evento.get("motivo", ""))
    seguinte = next((r for r in resultados if r.get("nivel") == evento.get("nivel")
                     and r["elapsed"] >= evento["elapsed"]), None)
    if seguinte is None:
        return "sem resultado"
    if seguinte.get("resultado") == "destravou":
        return "destravou"
    return "falhou: " + cell(seguinte.get("razao", ""))


def escada_linhas(escada, summary_path):
    """Escalonamentos, bloqueio, aprendizado e a curva de progresso até zerar."""
    resumo = {}
    if summary_path.exists():
        try:
            resumo = json.loads(summary_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            resumo = {}
    saida = ["", "## Escada de decisão (determinístico → Jev → GPT)", ""]
    apoios = (resumo.get("escada") or {}).get("apoios")
    if apoios is not None:
        saida.append("Apoios marcados: " + (", ".join(NIVEIS.get(a, a) for a in apoios) or "nenhum (só o determinístico)") + ".")
    custo = resumo.get("cost_by_level_usd") or {}
    if custo:
        saida.append("Custo estimado por nível: " + "; ".join(f"{NIVEIS.get(n, n)} US$ {v:.6f}" for n, v in custo.items()) + ".")
    saida.append("")
    saida += ["| Instante (s) | Quem | Por quê | Passo | Plano | Custo (US$) | Resultado |", "|---:|---|---|---|---|---:|---|"]
    for evento in escada["escalations"]:
        porque = ", ".join(SINAIS.get(s.get("tipo"), s.get("tipo", "?")) + (f" ({s['detalhe']})" if s.get("detalhe") else "")
                           for s in evento.get("sinais", [])) or "—"
        saida.append(f"| {evento['elapsed']:.1f} | {NIVEIS.get(evento.get('nivel'), evento.get('nivel'))} | {cell(porque)} | "
                     f"{cell(evento.get('passo'))} | {cell(' → '.join(evento.get('plano', [])) or '—')} | "
                     f"{float(evento.get('custo_usd', 0)):.6f} | {resultado_do_escalonamento(evento, escada['results'])} |")
    if not escada["escalations"]:
        saida.append("| — | — | Nenhum escalonamento nesta sessão | — | — | 0.000000 | — |")
    for negado in escada["denied"]:
        saida.append(f"- {negado['elapsed']:.1f} s — {NIVEIS.get(negado.get('nivel'), negado.get('nivel'))} barrado: {cell(negado.get('motivo'))}")
    if escada["locals"]:
        saida += ["", f"Recuperações locais iniciadas: {len(escada['locals'])}."]
    bloqueio = escada["blocked"]
    saida += ["", "### Bloqueio", ""]
    if bloqueio:
        saida.append(f"Em {bloqueio['elapsed']:.1f} s o passo `{cell(bloqueio.get('passo'))}` esgotou os apoios marcados. "
                     f"Posição {cell(bloqueio.get('posicao'))}; requisito {cell(bloqueio.get('requisito'))}; "
                     f"na mão {cell(bloqueio.get('na_mao'))}; recusas {cell(bloqueio.get('recusas'))}. "
                     "A captura final da sessão registra o que estava na tela.")
    else:
        saida.append("Nenhum passo esgotou os apoios.")
    saida += ["", "### Aprendizado (sinal → plano que funcionou)", ""]
    saida += [f"- {', '.join(SINAIS.get(x, x) for x in e.get('sinais', []))} → {NIVEIS.get(e.get('nivel'))}: "
              f"{' → '.join(e.get('plano', []))} (passo {cell(e.get('passo'))}). Candidato a regra do determinístico."
              for e in escada["learned"]] or ["Nenhum apoio destravou um passo nesta sessão."]
    progresso = resumo.get("progresso") or {}
    geral = progresso.get("progresso") or {}
    saida += ["", "## Progresso até zerar o jogo", ""]
    if geral.get("total"):
        saida.append(f"**{geral['percentual']:.1f}%** da história implementada: {geral['feitos']} de {geral['total']} passos. "
                     f"Capítulo: {cell(geral.get('capitulo'))} · {geral.get('capitulo_feitos', 0)}/{geral.get('capitulo_total', 0)}.")
        ritmo = progresso.get("ritmo") or {}
        if ritmo.get("acoes_por_passo") is not None:
            saida.append(f"Ritmo: {ritmo['acoes_por_passo']} ações e {segundos_texto(ritmo['segundos_por_passo'])} por passo; "
                         f"no ritmo atual faltam cerca de {ritmo['acoes_restantes']} ações ({segundos_texto(ritmo['segundos_restantes'])}).")
        distante = progresso.get("mais_distante") or {}
        saida.append(f"Ponto mais distante: {distante.get('feitos', 0)} passos ({distante.get('percentual', 0):.1f}%), "
                     f"na ação {distante.get('acoes', 0)}, aos {segundos_texto(distante.get('segundos'))} de jogo, "
                     f"em {cell(distante.get('capitulo'))}.")
        saida += ["", "| Capítulo | Passos | Destravado por |", "|---|---:|---|"]
        por_capitulo = progresso.get("destravado_por_capitulo") or {}
        for marco in geral.get("marcos", []):
            quem = ", ".join(f"{NIVEIS.get(n, n)} {q}" for n, q in (por_capitulo.get(marco["nome"]) or {}).items()) or "—"
            saida.append(f"| {cell(marco['nome'])}{' ◀' if marco.get('atual') else ''} | {marco['feitos']}/{marco['total']} | {quem} |")
    else:
        saida.append("Sem cadeias de missão observadas nesta sessão.")
    curva = escada["progress"]
    if curva:
        saida += ["", "Curva (progresso × ações):", "", "| Ação | Instante de jogo (s) | Progresso | Quem destravou |", "|---:|---:|---:|---|"]
        saida += [f"| {e.get('acoes_totais', '—')} | {e.get('segundos', 0)} | {float(e.get('percentual', 0)):.1f}% | "
                  f"{NIVEIS.get(e.get('destravou'), e.get('destravou'))} |" for e in curva]
    return saida


def alive(pid):
    if os.name == "nt":
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.GetExitCodeProcess.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong)]
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            return False
        code = ctypes.c_ulong()
        try:
            return bool(kernel.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == 259
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--watch", action="store_true", help="Update every 30 seconds while the session's Godot PID is alive.")
    args = parser.parse_args()
    pid_file = args.directory / "pid.txt"
    pid = int(pid_file.read_text()) if pid_file.exists() else 0
    while True:
        running = bool(pid) and alive(pid)
        print(generate(args.directory, live=running), flush=True)
        if not args.watch or not running:
            break
        time.sleep(30)
