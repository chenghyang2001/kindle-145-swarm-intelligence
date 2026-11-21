# K145《群體智能起義：讓千個AI自己開會、自己收場》互動演練

全書 10 章，每章一份 8 步互動演練（`practice/interactive/chNN.sh` ＋ 教練稿 `coach-chNN.txt`），
由長時程多代理工廠（`chenghyang2001/long-horizon-multiagent`，專案 `k145`）在 `factory/drills` 分支產出。

- `prompts/chNN.md`：各章重點與演練設計（依各章重點原創撰寫，不含書籍原文）。
- 本書沒有作者附的程式；每章練習用 Python 標準庫寫小模擬，放在 `practice/chNN/interactive/`。
- `practice/llm_agent.py`：用 `claude -p`（Max 訂閱，不設任何 API 金鑰）扮演真實子代理，每章最多呼叫 1～2 次。
- `practice/interactive/format-example-k142-*`：格式範例（取自 K142 第 2 章），只當格式參考。

執行：`cd practice/interactive && bash ch01.sh 1`（步驟 1～8）。
