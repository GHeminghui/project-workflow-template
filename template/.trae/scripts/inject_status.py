#!/usr/bin/env python3
"""SessionStart Hook: 读取项目状态并注入为会话上下文。

每次新建会话时自动执行，把 PROJECT_STATE.json 中的当前阶段、进度、
下一步动作作为附加上下文提供给智能体，使其无需询问即可知道该做什么。
"""
import json
import os
import sys


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

    idx = stage_order.index(current) if current in stage_order else -1
    stage_no = idx + 1 if idx >= 0 else "?"

    print("[项目状态自动加载]")
    print(f"项目名称: {state.get('project_name', '未命名')}")
    print(f"当前阶段: {stage_info.get('name', current)}（{current}, 第 {stage_no}/{len(stage_order)} 阶段）")
    print(f"阶段状态: {stage_info.get('status', '未知')}")
    print(f"下一步动作: {state.get('next_action', '未设置')}")

    checklist = stage_info.get("checklist", [])
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
