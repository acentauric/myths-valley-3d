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


def cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


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
    sampled_movement, presentation_seconds = 0.0, 0.0
    stalled, stall_start, stall_goal, stall_count = [], None, "", 0
    previous_decision = None
    last_objective = {}
    elapsed = 0.0
    complete = False
    stop = "em andamento" if live else "encerrado (consulte resumo.json)"
    start = None
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
            if kind == "decision":
                previous_decision = event
                presentation_seconds += max(0, float(event.get("latency_ms", 0))) / 1000
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
    if stall_start is not None and elapsed - stall_start >= 30:
        stalled.append((stall_goal, stall_start, elapsed, stall_count))
    lines += ["", "## Períodos sem progresso de missão, inventário ou obra", ""]
    lines += [f"- {cell(goal)}: {end - begin:.1f} s ({begin:.1f}–{end:.1f}), {count} ações sem mudança significativa."
              for goal, begin, end, count in stalled] or ["Nenhum intervalo registrado de pelo menos 30 segundos."]
    lines += ["", "## Evidências e análise contínua", "",
              "Analise etapas com muitas ações e poucos avanços, alternância repetida de movimentos e interações sem efeito. "
              "Cruze esses indícios com os frames e o JSONL antes de atribuir a causa ao jogo ou à política.", "",
              "[Eventos completos](eventos.jsonl) · [Saída do Godot](stdout.log) · [Erros do Godot](stderr.log)", ""]
    for screenshot in sorted(directory.glob("quadro_*.png")):
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
