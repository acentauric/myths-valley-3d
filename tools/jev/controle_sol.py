"""Read one observation or send an explicitly chosen action to a SOL session."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("directory", type=Path)
parser.add_argument("--action")
parser.add_argument("--reason", default="")
parser.add_argument("--brief", action="store_true")
args = parser.parse_args()
path = args.directory / "pending.json"
if not path.exists():
    print("WAITING: game loading or executing the previous action")
    raise SystemExit(0)
request = json.loads(path.read_text(encoding="utf-8"))
if args.action:
    if args.action not in request["actions"]:
        raise SystemExit("Action unavailable")
    answer = {"request_id": request["request_id"], "choice": args.action, "rationale": args.reason}
    temp = args.directory / "answer.tmp"
    temp.write_text(json.dumps(answer, ensure_ascii=False), encoding="utf-8")
    temp.replace(args.directory / "answer.json")
    print("SENT", answer)
else:
    state = request["state"]
    if args.brief:
        state = dict(state)
        state["recent_actions"] = state.get("recent_actions", [])[-3:]
        state["observations"] = [x.get("text", "") for x in state.get("observations", [])]
        actions = {k: v for k, v in request["actions"].items() if not k.startswith(("approach_", "explore_"))}
        required = request["current_task"].get("required_npc", {}).get("id", "")
        actions.update({k: v for k, v in request["actions"].items() if required and required in k})
    else:
        actions = request["actions"]
    keys = ("seconds", "position", "objective", "dialogue", "screen", "interaction_target",
            "inventory", "hand", "pedro", "observations", "recent_actions", "inventory_ui", "panel")
    print(json.dumps({"request_id": request["request_id"], "state": {k: state[k] for k in keys if k in state},
                      "task": request["current_task"], "actions": actions}, ensure_ascii=False))
