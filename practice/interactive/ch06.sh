#!/bin/bash
# K145 第 6 章互動演練：Agent Dynamics Network——時間演化的可視化，一次跑一步
# 用法：bash ch06.sh <步驟 1-8>
# 呼叫模型：只有第 6 步會呼叫模型 1 次（claude -p，透過 llm_agent.ask_json），其餘步驟全部離線
set -u
STEP="${1:-1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PRACTICE="$HERE/.."
WORK="$PRACTICE/ch06/interactive"
mkdir -p "$WORK"
G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'

banner() { clear; printf '%s╔══════════════════════════════════════════════════════╗%s\n' "$C" "$N"; printf '%s  K145 第 6 章｜代理動態網路　第 %s / 8 步%s\n' "$B" "$STEP" "$N"; printf '%s  %s%s\n' "$B" "$1" "$N"; printf '%s╚══════════════════════════════════════════════════════╝%s\n\n' "$C" "$N"; }
tip() { printf '%s💡 %s%s\n\n' "$Y" "$1" "$N"; }
show() { printf '%s▶ 要執行的程式：%s\n' "$G" "$N"; printf '%s' "$1" | sed "s/^/${G}  │ ${N}/"; printf '\n%s▶ 執行結果：%s\n' "$G" "$N"; }
run() { (cd "$PRACTICE" && PYTHONUTF8=1 PYTHONPATH=. python - <<PY
$1
PY
); printf '\n%s👉 第 %s 步完成%s\n' "$C" "$STEP" "$N"; }

case "$STEP" in
1) banner "四狀態機的時間演化：為什麼四成代理會掛著"
   tip "狀態機的價值不在標顏色，而在算出長期有多少比例的代理掛著。看「故障%」那一欄停在哪裡。"
   P='P = [
    [0.3, 0.6, 0.05, 0.05],
    [0.2, 0.5, 0.2, 0.1],
    [0.0, 0.0, 0.8, 0.2],
    [0.4, 0.3, 0.1, 0.2],
]
NAMES = ["空閒", "忙碌", "故障", "升級"]


def step(v):
    return [sum(v[i] * P[i][j] for i in range(4)) for j in range(4)]


print("書中 4x4 轉移矩陣（列 = 現在狀態，欄 = 下一步狀態）：")
print("{:<6}".format("") + "".join("{:>8}".format(n) for n in NAMES))
for n, row in zip(NAMES, P):
    print("{:<6}".format(n) + "".join("{:>8.2f}".format(x) for x in row))
print()
print("所有代理從「空閒」出發，各狀態比例隨時間演化（# 越多 = 故障越多）：")
print("{:>4} | {:>6} | {:>6} | {:>6} | {:>6} | {:<22} | {:>9}".format("步", "空閒%", "忙碌%", "故障%", "升級%", "故障比例", "存活檢查%"))
print("-" * 86)
v = [1.0, 0.0, 0.0, 0.0]
for t in range(51):
    if t in (0, 1, 2, 3, 5, 10, 20, 50):
        bar = "#" * int(v[2] * 50 + 0.5)
        print("{:>4} | {:>6.1f} | {:>6.1f} | {:>6.1f} | {:>6.1f} | {:<22} | {:>9.1f}".format(t, v[0] * 100, v[1] * 100, v[2] * 100, v[3] * 100, bar, (1 - v[2]) * 100))
    v = step(v)
print()
print("平均一旦故障要停留 1 / (1 - 0.8) = {:.0f} 步；忙碌每一步有 20% 掉進故障".format(1 / (1 - 0.8)))
print("「存活檢查」只問有沒有掛：長期看到約六成活著，卻看不出活著的代理裡有多少在靜默等待。")
print("書中案例：客服集群 40% 卡在「不忙也不報錯」，存活檢查全綠，追了六小時才找到上游 API 格式微調。")'
   show "$P"; run "$P" ;;
2) banner "練習 1-A：解析穩態 vs 1000 代理模擬，再修忙碌→故障"
   tip "解析解和模擬應該只差幾個百分點；如果差很多，就是模擬寫錯了。修完忙碌→故障，還剩兩成多是誰造成的？"
   P='import importlib
import json
import sys
from pathlib import Path

out = Path("ch06/interactive")
out.mkdir(parents=True, exist_ok=True)
(out / "adn_result.json").unlink(missing_ok=True)
SRC = """
import json
import random
from collections import deque
from pathlib import Path

OUT = Path(__file__).resolve().parent
SEED = 6
STATES = ["空閒", "忙碌", "故障", "升級"]
BOOK = [
    [0.3, 0.6, 0.05, 0.05],
    [0.2, 0.5, 0.2, 0.1],
    [0.0, 0.0, 0.8, 0.2],
    [0.4, 0.3, 0.1, 0.2],
]
FIXED = [row[:] for row in BOOK]
FIXED[1] = [0.35, 0.5, 0.05, 0.1]


def matmul(a, b):
    n, k, m = len(a), len(b), len(b[0])
    return [[sum(a[i][t] * b[t][j] for t in range(k)) for j in range(m)] for i in range(n)]


def steady(p, power=200):
    m = [row[:] for row in p]
    for _ in range(power - 1):
        m = matmul(m, p)
    return m[0]


def simulate_agents(p, agents=1000, steps=200, seed=SEED):
    rng = random.Random(seed)
    state = [0] * agents
    for _ in range(steps):
        for a in range(agents):
            r = rng.random()
            row = p[state[a]]
            acc, nxt = 0.0, len(row) - 1
            for j, pj in enumerate(row):
                acc += pj
                if r < acc:
                    nxt = j
                    break
            state[a] = nxt
    return [state.count(s) / agents for s in range(len(p))]


def part_a():
    return {
        "states": STATES,
        "book_matrix": BOOK,
        "fixed_matrix": FIXED,
        "steady_analytic": steady(BOOK),
        "simulated_1000x200": simulate_agents(BOOK),
        "steady_fixed": steady(FIXED),
    }


def print_a(a):
    print("A. 節點狀態機：穩態分佈（矩陣連乘 200 次）vs 1000 代理各跑 200 步")
    print("{:<4} | {:>9} | {:>13} | {:>12}".format("狀態", "解析穩態%", "1000代理模擬%", "差距(百分點)"))
    print("-" * 50)
    for i, s in enumerate(a["states"]):
        x, y = a["steady_analytic"][i] * 100, a["simulated_1000x200"][i] * 100
        print("{:<4} | {:>9.2f} | {:>13.2f} | {:>+12.2f}".format(s, x, y, y - x))
    gap = max(abs(x - y) for x, y in zip(a["steady_analytic"], a["simulated_1000x200"])) * 100
    print("最大差距 {:.2f} 個百分點（1000 個代理的抽樣誤差約 1.5 個百分點）".format(gap))
    print()
    print("把忙碌->故障從 0.2 改成 0.05（多出的 0.15 加到忙碌->空閒）：")
    print("{:<4} | {:>8} | {:>8}".format("狀態", "原矩陣%", "修正後%"))
    print("-" * 28)
    for i, s in enumerate(a["states"]):
        print("{:<4} | {:>8.2f} | {:>8.2f}".format(s, a["steady_analytic"][i] * 100, a["steady_fixed"][i] * 100))
    f0, f1 = a["steady_analytic"][2] * 100, a["steady_fixed"][2] * 100
    print("穩態故障比例 {:.2f}% -> {:.2f}%，降了 {:.2f} 個百分點".format(f0, f1, f0 - f1))
    print("還剩兩成多：故障->故障 0.8，一旦掛掉平均要卡 1/(1-0.8) = 5 步才離開")


def ws_graph(n, k=4, p=0.1, seed=SEED):
    rng = random.Random(seed)
    adj = [set() for _ in range(n)]
    for i in range(n):
        for j in range(1, k // 2 + 1):
            t = (i + j) % n
            adj[i].add(t)
            adj[t].add(i)
    for j in range(1, k // 2 + 1):
        for i in range(n):
            t = (i + j) % n
            if rng.random() < p and t in adj[i]:
                choices = [w for w in range(n) if w != i and w not in adj[i]]
                if choices:
                    w = rng.choice(choices)
                    adj[i].discard(t)
                    adj[t].discard(i)
                    adj[i].add(w)
                    adj[w].add(i)
    return adj


def bfs(adj, s):
    dist = {s: 0}
    q = deque([s])
    while q:
        u = q.popleft()
        for v in adj[u]:
            if v not in dist:
                dist[v] = dist[u] + 1
                q.append(v)
    return dist


def path_stats(adj, sources):
    total, count, ecc = 0, 0, 0
    for s in sources:
        d = bfs(adj, s)
        total += sum(d.values())
        count += len(d) - 1
        ecc = max(ecc, max(d.values()))
    return total / count, ecc


def clustering(adj):
    vals = []
    for u in range(len(adj)):
        nb = sorted(adj[u])
        k = len(nb)
        if k < 2:
            vals.append(0.0)
            continue
        links = sum(1 for i in range(k) for j in range(i + 1, k) if nb[j] in adj[nb[i]])
        vals.append(2.0 * links / (k * (k - 1)))
    return sum(vals) / len(vals)


def part_b():
    rows = []
    for n in (100, 1000):
        for p in (0.0, 0.1):
            adj = ws_graph(n, 4, p, seed=SEED)
            src = list(range(n)) if n <= 100 else random.Random(SEED).sample(range(n), 100)
            length, diam = path_stats(adj, src)
            rows.append({"N": n, "p": p, "L": length, "C": clustering(adj), "diameter_est": diam})
    return rows


def print_b(rows):
    print("B. 小世界衰減：Watts-Strogatz（環狀、每點連最近 k=4 個鄰居、重連機率 p）")
    print("{:>5} | {:>4} | {:>12} | {:>8} | {:>9}".format("N", "p", "特徵路徑長度", "聚類係數", "直徑(估)"))
    print("-" * 52)
    for r in rows:
        print("{:>5} | {:>4} | {:>12.2f} | {:>8.3f} | {:>9}".format(r["N"], r["p"], r["L"], r["C"], r["diameter_est"]))
    s = {(r["N"], r["p"]): r for r in rows}
    a, b = s[(100, 0.1)], s[(1000, 0.1)]
    print()
    print("重連 10%：N=100 路徑縮短 {:.1f} 倍；N=1000 路徑縮短 {:.1f} 倍".format(s[(100, 0.0)]["L"] / a["L"], s[(1000, 0.0)]["L"] / b["L"]))
    print("p=0.1 時 N 從 100 放大到 1000：路徑長度 {:.2f} -> {:.2f}（+{:.2f}），聚類係數 {:.3f} -> {:.3f}".format(a["L"], b["L"], b["L"] - a["L"], a["C"], b["C"]))
    print("書中指標「網路直徑 < 4」：N=100 {}，N=1000 {}".format("達成" if a["diameter_est"] < 4 else "未達成", "達成" if b["diameter_est"] < 4 else "未達成"))
    print("（N=1000 只從 100 個隨機起點做 BFS，直徑是下限估計）")


def ba_graph(n=300, m=2, seed=SEED):
    rng = random.Random(seed)
    adj = [set() for _ in range(n)]
    rep = []
    for a in range(m + 1):
        for b in range(a + 1, m + 1):
            adj[a].add(b)
            adj[b].add(a)
            rep += [a, b]
    for v in range(m + 1, n):
        chosen = set()
        while len(chosen) < m:
            chosen.add(rng.choice(rep))
        for t in sorted(chosen):
            adj[v].add(t)
            adj[t].add(v)
            rep += [v, t]
    return adj


def random_graph(n, edges, seed=SEED):
    rng = random.Random(seed)
    adj = [set() for _ in range(n)]
    made = 0
    while made < edges:
        a, b = rng.randrange(n), rng.randrange(n)
        if a != b and b not in adj[a]:
            adj[a].add(b)
            adj[b].add(a)
            made += 1
    return adj


def edge_count(adj):
    return sum(len(s) for s in adj) // 2


def giant_after(adj, removed):
    seen = set(removed)
    best = 0
    for s in range(len(adj)):
        if s in seen:
            continue
        seen.add(s)
        q = deque([s])
        size = 0
        while q:
            u = q.popleft()
            size += 1
            for v in adj[u]:
                if v not in seen:
                    seen.add(v)
                    q.append(v)
        best = max(best, size)
    return best / len(adj)


def part_c():
    ba = ba_graph(300, 2, seed=SEED)
    er = random_graph(300, edge_count(ba), seed=SEED)
    rows, degree = [], {}
    for name, g in (("偏好連結", ba), ("隨機網路", er)):
        n = len(g)
        rand_order = list(range(n))
        random.Random(SEED).shuffle(rand_order)
        hub_order = sorted(range(n), key=lambda v: (-len(g[v]), v))
        degree[name] = {"edges": edge_count(g), "max": max(len(s) for s in g), "ge10": sum(1 for s in g if len(s) >= 10)}
        for f in (0.0, 0.01, 0.05, 0.1, 0.2):
            k = round(n * f)
            rows.append({"network": name, "fraction": f, "removed": k,
                         "random": giant_after(g, rand_order[:k]),
                         "targeted": giant_after(g, hub_order[:k])})
    return {"degree": degree, "rows": rows}


def print_c(c):
    print("C. 級聯失效：偏好連結網路 vs 同點數同邊數的隨機網路（N=300）")
    for name, info in c["degree"].items():
        print("  {}：邊數 {}，最大度數 {}，度數 >= 10 的節點 {} 個".format(name, info["edges"], info["max"], info["ge10"]))
    print()
    print("{:<6} | {:>5} | {:>6} | {:>14} | {:>17}".format("網路", "移除%", "移除數", "隨機移除 GCC%", "先打度數最高 GCC%"))
    print("-" * 62)
    for r in c["rows"]:
        print("{:<6} | {:>5.0f} | {:>6} | {:>14.1f} | {:>17.1f}".format(r["network"], r["fraction"] * 100, r["removed"], r["random"] * 100, r["targeted"] * 100))
    ba = {r["fraction"]: r for r in c["rows"] if r["network"] == "偏好連結"}
    er = {r["fraction"]: r for r in c["rows"] if r["network"] == "隨機網路"}
    print("（GCC% = 最大連通元件節點數 / 原本 300 個節點）")
    print()
    print("先打度數最高的 20%：偏好連結剩 {:.1f}%，隨機網路剩 {:.1f}%".format(ba[0.2]["targeted"] * 100, er[0.2]["targeted"] * 100))
    print("隨機移除 20%：偏好連結剩 {:.1f}%，隨機網路剩 {:.1f}%".format(ba[0.2]["random"] * 100, er[0.2]["random"] * 100))
    worse = "偏好連結" if ba[0.2]["targeted"] < er[0.2]["targeted"] else "隨機網路"
    print("被針對攻擊時崩得比較快的是：" + worse)


def run_all():
    result = {"A": part_a(), "B": part_b(), "C": part_c()}
    (OUT / "adn_result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return result


if __name__ == "__main__":
    res = run_all()
    print_a(res["A"])
    print()
    print_b(res["B"])
    print()
    print_c(res["C"])
    print()
    print("已寫入", OUT / "adn_result.json")
"""
(out / "adn_sim.py").write_text(SRC, encoding="utf-8")
sys.path.insert(0, str(out.resolve()))
importlib.invalidate_caches()
import adn_sim

a = adn_sim.part_a()
adn_sim.print_a(a)
(out / "adn_result.json").write_text(json.dumps({"A": a}, ensure_ascii=False, indent=2), encoding="utf-8")
print()
print("已寫入", out / "adn_sim.py", "與", out / "adn_result.json", "（目前只有 A 段）")'
   show "$P"; run "$P" ;;
3) banner "練習 1-B：小世界在規模放大時衰減"
   tip "p=0 的兩列是對照組，數字可以手算：環狀網路平均要走 N/8 步左右。重點看 p=0.1 的兩列 N 放大後的變化。"
   P='import importlib
import json
import sys
from pathlib import Path

out = Path("ch06/interactive")
if not (out / "adn_sim.py").exists():
    print("找不到 ch06/interactive/adn_sim.py，請先跑第 2 步。")
    raise SystemExit(0)
sys.path.insert(0, str(out.resolve()))
importlib.invalidate_caches()
import adn_sim

rows = adn_sim.part_b()
adn_sim.print_b(rows)
res_path = out / "adn_result.json"
try:
    res = json.loads(res_path.read_text(encoding="utf-8"))
except (OSError, ValueError):
    res = {}
res["B"] = rows
res_path.write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
print()
print("已把 B 段寫入", res_path, "；目前含：", sorted(res))'
   show "$P"; run "$P" ;;
4) banner "練習 1-C：超級節點的代價——級聯失效"
   tip "兩個網路邊數一模一樣（597 條），差別只在邊怎麼分佈。看 20% 那兩列的「先打度數最高 GCC%」。"
   P='import importlib
import json
import sys
from pathlib import Path

out = Path("ch06/interactive")
if not (out / "adn_sim.py").exists():
    print("找不到 ch06/interactive/adn_sim.py，請先跑第 2 步。")
    raise SystemExit(0)
sys.path.insert(0, str(out.resolve()))
importlib.invalidate_caches()
import adn_sim

c = adn_sim.part_c()
adn_sim.print_c(c)
res_path = out / "adn_result.json"
try:
    res = json.loads(res_path.read_text(encoding="utf-8"))
except (OSError, ValueError):
    res = {}
res["C"] = c
res_path.write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
print()
print("已把 C 段寫入", res_path, "；目前含：", sorted(res))
print("想一次重算 A、B、C：PYTHONUTF8=1 python ch06/interactive/adn_sim.py")'
   show "$P"; run "$P" ;;
5) banner "邊層：向量時鐘、交付保證、Gossip、一條慢 200 ms 的邊"
   tip "D 段的表是書中金融投顧網路「慢 200 毫秒、流量掉 60%」的算術版：每筆延遲變長，同樣的併發數就只能做更少的事。"
   P='import json
import random
from pathlib import Path

out = Path("ch06/interactive")
out.mkdir(parents=True, exist_ok=True)
(out / "edge_layer.json").unlink(missing_ok=True)
result = {}


def compare(a, b):
    le = all(x <= y for x, y in zip(a, b))
    ge = all(x >= y for x, y in zip(a, b))
    if le and ge:
        return "相同"
    if le:
        return "前者先發生（可能是因）"
    if ge:
        return "後者先發生（可能是因）"
    return "並行（彼此沒有因果）"


print("A. 向量時鐘：書中範例 A=[5,3,2]、B=[4,7,3]（三格分別是代理 A、B、C 的計數）")
A, B = [5, 3, 2], [4, 7, 3]
merged = [max(x, y) for x, y in zip(A, B)]
std = merged[:]
std[1] += 1
print("  A vs B：", compare(A, B))
print("  B 收到 A 的訊息，逐格取最大值：", merged, "（書中寫法）")
print("  標準做法再把 B 自己那一格 +1：", std)
print("  A vs 更新後的 B：", compare(A, std))
print("  舊 B vs 更新後的 B：", compare(B, std))
print("  陷阱：只比總和（A 是 10、B 是 14）會以為 A 先於 B，其實兩者並行")
result["vector_clock"] = {"A": A, "B": B, "A_vs_B": compare(A, B), "merged_book": merged, "merged_standard": std}
print()

print("B. 交付保證：1000 則訊息，訊息與確認（ack）各有 10% 會掉")
rng = random.Random(6)
LOSS, M, MAX_TRY = 0.1, 1000, 10
amo = sum(1 for _ in range(M) if rng.random() >= LOSS)
sends = deliveries = unique = 0
for _m in range(M):
    got = False
    for _t in range(MAX_TRY):
        sends += 1
        if rng.random() < LOSS:
            continue
        deliveries += 1
        got = True
        if rng.random() >= LOSS:
            break
    unique += 1 if got else 0
dup = deliveries - unique
print("{:<8} | {:>8} | {:>10} | {:>8} | {:>4} | {:>4}".format("保證", "傳送次數", "接收端處理", "不同訊息", "遺失", "重複"))
print("-" * 58)
print("{:<8} | {:>8} | {:>10} | {:>8} | {:>4} | {:>4}".format("最多一次", M, amo, amo, M - amo, 0))
print("{:<8} | {:>8} | {:>10} | {:>8} | {:>4} | {:>4}".format("至少一次", sends, deliveries, unique, M - unique, dup))
print("{:<8} | {:>8} | {:>10} | {:>8} | {:>4} | {:>4}".format("精確一次", sends, unique, unique, M - unique, 0))
print("  精確一次 = 至少一次的同一份傳輸紀錄 + 接收端用訊息 id 去重，擋掉了 {} 次重複處理".format(dup))
result["delivery"] = {"at_most_once": amo, "sends": sends, "deliveries": deliveries, "unique": unique, "duplicates": dup}
print()

print("C. Gossip 擴散：1000 個節點，每個已知節點每輪隨機推給 2 個節點，每則 10% 會掉")
rng = random.Random(6)
N, FAN = 1000, 2
informed = {0}
hist = [(0, 1)]
msgs = 0
while len(informed) < N and len(hist) <= 60:
    new = set()
    for u in sorted(informed):
        for _ in range(FAN):
            msgs += 1
            v = rng.randrange(N)
            if rng.random() >= LOSS:
                new.add(v)
    informed |= new
    hist.append((len(hist), len(informed)))
for r, cnt in hist:
    print("  第 {:>2} 輪：已知 {:>4} 個（{:>5.1f}%）".format(r, cnt, cnt / N * 100))
r99 = next(r for r, cnt in hist if cnt >= 0.99 * N)
rfull = hist[-1][0] if hist[-1][1] == N else None
print("  到 99% 要 {} 輪；全部收到要 {} 輪（最終一致性延遲）；總共發了 {} 則訊息".format(r99, rfull, msgs))
print("  對照：由單一中心可靠地逐一送給 999 個節點，約要傳 {:.0f} 次，而且全部從同一個節點發出".format(999 / ((1 - LOSS) ** 2)))
result["gossip"] = {"history": hist, "round_99": r99, "round_full": rfull, "messages": msgs}
print()

print("D. 一條邊慢 200 ms：20 個代理都要等同一個資料源，流量 = 併發數 / 每筆延遲")
W = 20
rows = []
print("{:>10} | {:>11} | {:>13} | {:>8}".format("平常延遲ms", "平常 筆/秒", "慢200ms 筆/秒", "流量掉%"))
print("-" * 52)
for base in (50, 100, 130, 200):
    t0 = W / (base / 1000)
    t1 = W / ((base + 200) / 1000)
    drop = (1 - t1 / t0) * 100
    rows.append({"base_ms": base, "normal": t0, "slow": t1, "drop_pct": drop})
    print("{:>10} | {:>11.1f} | {:>13.1f} | {:>8.1f}".format(base, t0, t1, drop))
print("  沒有任何節點掛掉、存活監控全綠，流量卻掉五到八成：局部一條邊變慢，會被結構放大成全域問題。")
result["slow_edge"] = rows

(out / "edge_layer.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print()
print("已寫入", out / "edge_layer.json")'
   show "$P"; run "$P" ;;
6) banner "練習 2 前半：讓真實模型當監控代理"
   tip "這一步會呼叫模型 1 次（claude -p），最多等 180 秒；模型每次回答可能不同，照實記錄。提示詞只給類型名稱，不告訴模型判斷規則。"
   P='import importlib
import json
import sys
from pathlib import Path

out = Path("ch06/interactive")
out.mkdir(parents=True, exist_ok=True)
raw = out / "monitor_raw.json"
raw.unlink(missing_ok=True)
SRC = """
import json
import random
import sys
from pathlib import Path

PRACTICE = Path(__file__).resolve().parents[2]
if str(PRACTICE) not in sys.path:
    sys.path.insert(0, str(PRACTICE))

OUT = Path(__file__).resolve().parent
CODE = {"idle": "I", "busy": "B", "failed": "F", "upgrading": "U"}
TYPES = ("silent_wait", "sub_healthy", "failed")
STEPS = 20


def make_logs(seed=66):
    rng = random.Random(seed)
    ids = ["A{:02d}".format(i) for i in range(12)]
    pick = rng.sample(range(12), 4)
    truth = {ids[pick[0]]: "silent_wait", ids[pick[1]]: "silent_wait",
             ids[pick[2]]: "sub_healthy", ids[pick[3]]: "failed"}
    logs = {}
    for aid in ids:
        kind = truth.get(aid)
        states, ms = [], []
        for t in range(1, STEPS + 1):
            if kind == "silent_wait" and t >= 8:
                s, v = "busy", 0
            elif kind == "sub_healthy":
                s, v = "busy", rng.randint(80, 160) * 10
            elif kind == "failed" and t >= 12:
                s, v = "failed", 0
            else:
                r = rng.random()
                if r < 0.35:
                    s, v = "idle", rng.randint(5, 15)
                elif r < 0.92:
                    s, v = "busy", rng.randint(80, 160)
                elif r < 0.97:
                    s, v = "upgrading", rng.randint(20, 40)
                else:
                    s, v = "failed", 0
            states.append(s)
            ms.append(v)
        logs[aid] = {"states": states, "ms": ms}
    return logs, truth


def build_prompt(logs):
    example = {"alerts": [{"agent_id": "A00", "type": "silent_wait|sub_healthy|failed", "evidence": "你從紀錄看到的證據"}],
               "root_cause_guess": "你對整體根因的猜測"}
    lines = [
        "你是 Agent Dynamics Network 的監控代理。下面是 12 個代理、各 20 步的狀態紀錄。",
        "狀態代碼：I=idle、B=busy、F=failed、U=upgrading；ms 是每一步的回應時間（毫秒）。",
        "",
        "代理 | 第1到20步狀態 | 第1到20步回應時間ms",
    ]
    for aid, rec in logs.items():
        lines.append(aid + " | " + "".join(CODE[s] for s in rec["states"]) + " | " + " ".join(str(v) for v in rec["ms"]))
    lines += [
        "",
        "請找出需要告警的代理。type 只能是 silent_wait（靜默等待）、sub_healthy（亞健康）、failed（持續故障）之一；正常的代理不要列出。",
        "每個 alert 的 evidence 要指出是哪幾步、什麼數字。",
        "輸出格式：" + json.dumps(example, ensure_ascii=False),
    ]
    return chr(10).join(lines)


def norm_id(x):
    s = str(x).strip().upper()
    digits = "".join(ch for ch in s if ch.isdigit())
    return "A{:02d}".format(int(digits)) if digits else s


def grade(reply, truth):
    alerts = reply.get("alerts") if isinstance(reply, dict) else None
    if not isinstance(alerts, list):
        alerts = []
    pred = {}
    for a in alerts:
        if isinstance(a, dict):
            aid = norm_id(a.get("agent_id", ""))
            if aid and aid not in pred:
                pred[aid] = str(a.get("type", "")).strip().lower()
    hits = sorted(a for a in truth if pred.get(a) == truth[a])
    wrong = sorted([a, pred[a], truth[a]] for a in truth if a in pred and pred[a] != truth[a])
    missed = sorted(a for a in truth if a not in pred)
    false_pos = sorted(a for a in pred if a not in truth)
    per_type = {t: {"should": sum(1 for a in truth if truth[a] == t),
                    "hit": sum(1 for a in hits if truth[a] == t)} for t in TYPES}
    return {"pred": pred, "hits": hits, "wrong_type": wrong, "missed": missed,
            "false_positive": false_pos, "per_type": per_type,
            "precision": len(hits) / len(pred) if pred else 0.0,
            "recall": len(hits) / len(truth) if truth else 0.0}


def rule_detect(logs):
    busy = sorted(v for rec in logs.values() for s, v in zip(rec["states"], rec["ms"]) if s == "busy" and v > 0)
    med = busy[len(busy) // 2]
    found = {}
    for aid, rec in logs.items():
        run_zero = best_zero = run_f = best_f = 0
        for s, v in zip(rec["states"], rec["ms"]):
            run_zero = run_zero + 1 if (s == "busy" and v == 0) else 0
            best_zero = max(best_zero, run_zero)
            run_f = run_f + 1 if s == "failed" else 0
            best_f = max(best_f, run_f)
        own = sorted(v for s, v in zip(rec["states"], rec["ms"]) if s == "busy" and v > 0)
        if best_zero >= 5:
            found[aid] = "silent_wait"
        elif best_f > 5:
            found[aid] = "failed"
        elif own and own[len(own) // 2] > 5 * med:
            found[aid] = "sub_healthy"
    return found, med


def main():
    from llm_agent import ask_json
    logs, truth = make_logs()
    reply = ask_json(build_prompt(logs))
    found, med = rule_detect(logs)
    data = {"truth": truth, "model_reply": reply, "grade": grade(reply, truth),
            "rule_baseline": grade({"alerts": [{"agent_id": a, "type": t} for a, t in found.items()]}, truth),
            "busy_median_ms": med}
    (OUT / "monitor_agent.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(data["grade"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
"""
(out / "monitor_agent.py").write_text(SRC, encoding="utf-8")
sys.path.insert(0, str(out.resolve()))
importlib.invalidate_caches()
import monitor_agent as ma
from llm_agent import ask_json

logs, truth = ma.make_logs()
(out / "monitor_logs.json").write_text(json.dumps({"logs": logs, "truth": truth}, ensure_ascii=False, indent=2), encoding="utf-8")
print("12 個代理 x 20 步（I=空閒 B=忙碌 F=故障 U=升級）：")
for aid, rec in logs.items():
    ms = sorted(rec["ms"])
    print("  {}  {}  回應時間中位數 {:>5} ms，0 ms 的步數 {:>2}".format(aid, "".join(ma.CODE[s] for s in rec["states"]), ms[10], rec["ms"].count(0)))
prompt = ma.build_prompt(logs)
print()
print("送給模型的提示詞長度：", len(prompt), "字元；呼叫 claude -p 1 次（最多 180 秒）...")
try:
    reply = ask_json(prompt)
except (RuntimeError, ValueError) as exc:
    print("呼叫模型失敗：", exc)
    print("第 7 步會改用內建範例回覆繼續。")
    raise SystemExit(0)
raw.write_text(json.dumps(reply, ensure_ascii=False, indent=2), encoding="utf-8")
alerts = reply.get("alerts") if isinstance(reply.get("alerts"), list) else []
print("模型發出的警報：", len(alerts), "則")
for a in alerts:
    if isinstance(a, dict):
        print("  {:<5} {:<12} {}".format(str(a.get("agent_id")), str(a.get("type")), str(a.get("evidence", ""))[:50]))
print()
print("模型猜的根因：", str(reply.get("root_cause_guess", ""))[:200])
print("已寫入", raw)'
   show "$P"; run "$P" ;;
7) banner "練習 2 後半：用程式規則對答案"
   tip "特別看 silent_wait 有沒有被當成「正常忙碌」、sub_healthy 有沒有被漏掉——這兩種正是「存活／死亡」二分法看不到的。"
   P='import importlib
import json
import sys
from pathlib import Path

out = Path("ch06/interactive")
if not (out / "monitor_agent.py").exists():
    print("找不到 ch06/interactive/monitor_agent.py，請先跑第 6 步。")
    raise SystemExit(0)
(out / "monitor_agent.json").unlink(missing_ok=True)
sys.path.insert(0, str(out.resolve()))
importlib.invalidate_caches()
import monitor_agent as ma

logs, truth = ma.make_logs()
raw = out / "monitor_raw.json"
reply = None
if raw.exists():
    try:
        reply = json.loads(raw.read_text(encoding="utf-8"))
    except ValueError:
        reply = None
if isinstance(reply, dict):
    source = "第 6 步模型輸出"
else:
    normal = sorted(a for a in logs if a not in truth)
    alerts = [{"agent_id": a, "type": t, "evidence": "內建範例"} for a, t in sorted(truth.items()) if t != "sub_healthy"]
    alerts.append({"agent_id": normal[0], "type": "failed", "evidence": "內建範例：把偶發一步故障當成持續故障"})
    reply = {"alerts": alerts, "root_cause_guess": "上游 API 回傳格式改變，代理在等一個永遠不會來的欄位"}
    source = "內建範例（第 6 步沒有成功）"

g = ma.grade(reply, truth)
found, med = ma.rule_detect(logs)
rule = ma.grade({"alerts": [{"agent_id": a, "type": t} for a, t in found.items()]}, truth)

print("資料來源：", source)
print("標準答案：", "、".join("{}={}".format(a, t) for a, t in sorted(truth.items())))
print()
print("{:<12} | {:>4} | {:>8} | {:>8}".format("類型", "應抓", "模型抓對", "規則抓對"))
print("-" * 42)
for t in ma.TYPES:
    print("{:<12} | {:>4} | {:>8} | {:>8}".format(t, g["per_type"][t]["should"], g["per_type"][t]["hit"], rule["per_type"][t]["hit"]))
print("{:<12} | {:>4} | {:>8} | {:>8}".format("合計", len(truth), len(g["hits"]), len(rule["hits"])))
print()
print("模型：抓對 {}、類型判錯 {}、漏抓 {}、誤報 {}；精確率 {:.2f}、召回率 {:.2f}".format(
    len(g["hits"]), len(g["wrong_type"]), len(g["missed"]), len(g["false_positive"]), g["precision"], g["recall"]))
if g["wrong_type"]:
    print("  類型判錯（代理, 模型說, 答案）：", g["wrong_type"])
if g["missed"]:
    print("  漏抓：", g["missed"])
if g["false_positive"]:
    print("  誤報：", g["false_positive"])
print("規則基準：抓對 {}、誤報 {}（全體 busy 回應時間中位數 {} ms，亞健康門檻 5 倍 = {} ms）".format(
    len(rule["hits"]), len(rule["false_positive"]), med, 5 * med))
print("模型的根因猜測：", str(reply.get("root_cause_guess", ""))[:150])

data = {"source": source, "truth": truth, "model_reply": reply, "grade": g,
        "rule_baseline": rule, "busy_median_ms": med}
(out / "monitor_agent.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
print()
print("已寫入", out / "monitor_agent.json")'
   show "$P"; run "$P" ;;
8) banner "總結：節點、邊、結構三層各留下什麼數字"
   tip "指標要說得出「量到多少算成功、多少算失敗」；下面每個指標都有一個你剛剛親手量出來的數字。"
   P='import json
from pathlib import Path

out = Path("ch06/interactive")
points = [
    "節點層：四狀態機＋轉移矩陣能算出長期分佈。書中矩陣的穩態故障約 40.1%（忙碌每步 20% 掉進故障、故障留在故障 0.8），這是架構問題不是運氣；把忙碌->故障降到 0.05 也只降到約 22.4%，故障的自我停留同樣要處理。",
    "結構層：小世界不是免費的。k=4 的環狀網路重連 10% 就讓路徑大幅縮短，但 N 從 100 放大到 1000 時，路徑長度與直徑又變長，「直徑 < 4」在低度數網路上做不到。",
    "超級節點是雙面刃：偏好連結讓少數節點度數很高、協調很快，但先打度數最高的節點時，最大連通元件掉得比同邊數的隨機網路快——快與韌要取捨，沒有絕對答案。",
    "邊層：一條邊慢 200 ms、沒有任何節點掛掉，流量就掉 60.6%；向量時鐘 [5,3,2] 與 [4,7,3] 其實是並行；至少一次會重複、最多一次會遺失、精確一次要靠接收端去重。",
    "監控要可驗證：「存活／死亡」看不到靜默等待與亞健康；不管模型講得多頭頭是道，都要用程式規則對標準答案，算出抓對、漏抓、誤報。",
]
print("第 6 章重點：")
for i, p in enumerate(points, 1):
    print("  {}. {}".format(i, p))
print()


def load(name):
    try:
        return json.loads((out / name).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


adn, edge, mon = load("adn_result.json"), load("edge_layer.json"), load("monitor_agent.json")
print("作者的三個可驗證指標，本次演練量到：")
if adn and "B" in adn:
    d = {r["N"]: r["diameter_est"] for r in adn["B"] if r["p"] > 0}
    print("  1. 網路直徑 < 4：N=100 直徑 {}、N=1000 直徑 {} -> {}".format(d.get(100), d.get(1000), "達成" if max(d.values()) < 4 else "未達成"))
else:
    print("  1. 網路直徑 < 4：缺資料（請先跑第 3 步）")
if adn and "C" in adn:
    t = {r["network"]: r["targeted"] for r in adn["C"]["rows"] if abs(r["fraction"] - 0.2) < 1e-9}
    print("  2. 級聯失效閾值：先打度數最高 20% 後，偏好連結剩 {:.1f}%、隨機網路剩 {:.1f}%".format(t.get("偏好連結", 0) * 100, t.get("隨機網路", 0) * 100))
else:
    print("  2. 級聯失效閾值：缺資料（請先跑第 4 步）")
if edge and "gossip" in edge:
    gsp = edge["gossip"]
    print("  3. 最終一致性延遲：Gossip 到 99% 要 {} 輪、全部收到要 {} 輪".format(gsp.get("round_99"), gsp.get("round_full")))
else:
    print("  3. 最終一致性延遲：缺資料（請先跑第 5 步）")
if mon:
    print("  另：監控代理（{}）召回率 {:.2f}，規則基準召回率 {:.2f}".format(mon.get("source"), mon["grade"]["recall"], mon["rule_baseline"]["recall"]))
print()
print("本章產出檔案：")
for name in ("adn_sim.py", "adn_result.json", "edge_layer.json", "monitor_agent.py", "monitor_logs.json", "monitor_raw.json", "monitor_agent.json"):
    p = out / name
    print("  {} {}".format("OK" if p.exists() else "缺", p))'
   show "$P"; run "$P" ;;
*) echo "步驟要 1～8" ;;
esac
