#!/usr/bin/env python3
"""SessionStart Hook: 读取项目状态并注入为会话上下文。

每次新建会话时自动执行，把 PROJECT_STATE.json 中的当前阶段、进度、
下一步动作作为附加上下文提供给智能体，使其无需询问即可知道该做什么。

「下一步动作」不存字段，而是取当前阶段第一个未完成的 checklist 项——
避免与 checklist 构成双重真相而变陈旧。

项目处于 rejected / archived 时只提示状态并停止推动阶段。
"""
import json
import os
import sys

STATUS_LABELS = {
    "active": "进行中",
    "rejected": "已否决（No-Go）",
    "archived": "已归档",
}


def main() -> int:
    project_dir = os.environ.get("TRAE_PROJECT_DIR") or os.getcwd()
    state_file = os.path.join(project_dir, "PROJECT_STATE.json")

    if not os.path.exists(state_file):
        print("[项目状态] 未找到 PROJECT_STATE.json。")
        print("若这是新项目，请运行 /init-project 初始化；否则请检查状态文件是否存在。")
        return 0

    try:
        with open(state_file, "r", encoding="utf-8") as f:
            state = json.load(f)
    except (json.JSONDecodeError, OSError) as exc:
        print(f"[项目状态] 读取 PROJECT_STATE.json 失败：{exc}")
        return 0

    stage_order = state.get("stage_order", [])
    current = state.get("current_stage", "")
    stages = state.get("stages", {})
    stage_info = stages.get(current, {})
    project_status = state.get("project_status", "active")

    idx = stage_order.index(current) if current in stage_order else -1
    stage_no = idx + 1 if idx >= 0 else "?"

    print("[项目状态自动加载]")
    print(f"项目名称: {state.get('project_name', '未命名')}")
    print(f"项目状态: {STATUS_LABELS.get(project_status, project_status)}")
    print(f"当前阶段: {stage_info.get('name', current)}（{current}, 第 {stage_no}/{len(stage_order)} 阶段）")
    print(f"阶段状态: {stage_info.get('status', '未知')}")

    if project_status != "active":
        print("---")
        if project_status == "rejected":
            print("本项目已在调研阶段判定 No-Go，流程终止，请勿继续推进阶段。")
            print("如需重启：人工把 project_status 改回 active，并将 current_stage 调回 discovery 后重新评估。")
        else:
            print("本项目已归档，流程结束，请勿继续推进阶段。")
            print("如需继续迭代：见 AGENTS.md 中「关于迭代」的说明（新建项目周期，不在本项目内回退阶段）。")
        return 0

    checklist = stage_info.get("checklist", [])
    pending = [item for item in checklist if not item.get("done")]

    if pending:
        print(f"下一步动作: {pending[0].get('item', '')}")
    elif checklist:
        print("下一步动作: 本阶段清单已全部完成，提示用户运行 /advance 推进")
    else:
        print("下一步动作: 当前阶段无清单项")

    if checklist:
        print("本阶段清单:")
        for item in checklist:
            mark = "[x]" if item.get("done") else "[ ]"
            print(f"  {mark} {item.get('item', '')}")

    print("---")
    print("请基于以上状态继续当前阶段的工作。")
    print("如需查看完整进度可运行 /status；当前阶段清单全部完成后，提示用户运行 /advance 推进。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
