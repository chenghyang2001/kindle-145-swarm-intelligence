#!/bin/bash
# K142 第 2 章互動演練：自主性與 CapabilityBudget（能力預算），一次跑一步
# 用法：bash ch02.sh <步驟 1-8>
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HERE/../HarnessLab"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K142 第 2 章｜自主性：CapabilityBudget　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$LAB" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$PRE
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

# 每一步共用：建立一份能力預算＋一個「做一次工具呼叫」的小函式
PRE='from harnesslab.core import CapabilityBudget, ToolCall, ActionRisk, DataClass
budget = CapabilityBudget(
    tool_limits={"patch_repo": 2},                       # 工具額度：改程式最多 2 次
    risk_limits={ActionRisk.REVERSIBLE_WRITE: 3},        # 風險額度：可回復寫入總共 3 次
    approvals_required=frozenset({ActionRisk.EXTERNAL_COMMUNICATION, ActionRisk.PRIVILEGED_OPERATION}),
)
def call(tool, risk, intent="修補 billing-api 的漏洞套件"):
    return ToolCall(tool=tool, args={}, data_class=DataClass.INTERNAL, side_effect=risk, intent=intent)
def act(tool, risk, spend=True):
    c = call(tool, risk); d = budget.check(c)
    if d.allowed and spend: budget.spend(c)
    print(f"  {tool:<14} 風險={risk.value:<22} → {d.decision.value.upper():<8} 原因：{d.reason}")
    return d'

case "$STEP" in
1) banner "建立一份能力預算"
   tip "自主性不是開關，是一道梯子。預算規定：改程式最多 2 次、可回復寫入共 3 次、對外通訊與特權操作一律要人核准。"
   P='print("工具額度：", budget.tool_limits)
print("風險額度：", {k.value: v for k, v in budget.risk_limits.items()})
print("需要人核准：", sorted(r.value for r in budget.approvals_required))'
   show "$P"; run "$P" ;;
2) banner "低風險讀取：自動放行"
   tip "讀工單是唯讀動作，沒有設額度、也不在核准清單，所以代理可以自己做。"
   P='act("read_ticket", ActionRisk.READ)
act("read_ticket", ActionRisk.READ)'
   show "$P"; run "$P" ;;
3) banner "改程式：額度用完就擋"
   tip "patch_repo 只給 2 次。第 3 次不是交人審，而是直接 DENY：額度本身就是硬上限。"
   P='for i in range(3):
    act("patch_repo", ActionRisk.REVERSIBLE_WRITE)
print("已用：", dict(budget.spent_tools))'
   show "$P"; run "$P" ;;
4) banner "風險額度：換工具也繞不過"
   tip "工具額度管單一工具，風險額度管同一類動作。先改兩次程式，再換別的寫入工具，第 4 次可回復寫入一樣被擋。"
   P='act("patch_repo", ActionRisk.REVERSIBLE_WRITE)
act("patch_repo", ActionRisk.REVERSIBLE_WRITE)
act("update_config", ActionRisk.REVERSIBLE_WRITE)
act("write_cache", ActionRisk.REVERSIBLE_WRITE)
print("風險已用：", {k.value: v for k, v in budget.spent_risks.items()})'
   show "$P"; run "$P" ;;
5) banner "對外寄信：交給人核准"
   tip "寄信給客戶屬於對外通訊，結果不是放行也不是拒絕，而是 ESCALATE：進核准佇列，等人決定。"
   P='act("send_email", ActionRisk.EXTERNAL_COMMUNICATION)
act("rotate_secret", ActionRisk.PRIVILEGED_OPERATION)'
   show "$P"; run "$P" ;;
6) banner "陷阱：只檢查、不扣額度"
   tip "check 只回答「現在可不可以」，不會自己扣額度；要呼叫 spend 才算用掉。harness 若忘了 spend，額度形同虛設。"
   P='print("忘了 spend：")
for i in range(4):
    act("patch_repo", ActionRisk.REVERSIBLE_WRITE, spend=False)
print("已用：", dict(budget.spent_tools), "← 一次都沒扣")'
   show "$P"; run "$P" ;;
7) banner "跑書附第 2 章完整情境"
   tip "作者的情境把預算、核准佇列、回滾掛鉤、不可豁免的控制串在一起。看每個決策是 allow、deny 還是 escalate。"
   P='import json, runpy
from chapters.ch02.scenario import run as ch02_run
r = ch02_run()
print(f"通過={r.passed} 分數={r.score}  {r.summary}\n")
for d in r.decisions:
    print("  " + d.decision.value.upper().ljust(9) + d.reason[:80])'
   show "$P"; run "$P" ;;
8) banner "總結：預算在 harness 的位置"
   tip "模型提出動作 → harness 先查意圖、身分，再由 CapabilityBudget 決定放行、擋下或交人 → 放行才扣額度並執行。預算讓代理能自己做事，但做多少、做多危險，由程式說了算。"
   P='print("""  ALLOW    ：低風險、額度內 → 代理自己做
  DENY     ：工具或風險額度用完 → 硬擋，不給商量
  ESCALATE ：對外通訊、特權操作 → 進核准佇列等人
  關鍵：check 之後一定要 spend，否則額度不會減少""")'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
