# OISS 從 0 手刻教學

## 1. 先看懂題目（只抓重點）
- 8 條指令，每條 12 bit：`[11:9]opcode [8:6]rs [5:3]rt [2:0]rd`；指令 0 在最低 12 bit。
- 每個 opcode 有自己的 latency（`Inst_latency_I[6*opcode +: 6]`）。
- 輸出：發射順序 `Inst_order_O`（每格 3 bit，最低格先發射）與最小完成週期 `Ex_cycle`。
- 規則：每週期最多發射 1 條；嚴格按輸出順序發射（下一條沒準備好就 stall）；
  `start[order[k]] = max(start[order[k-1]]+1, 所有前驅的 finish)`，`finish = start + latency`。
- 必須純組合電路、不能有 latch、不能用 `error/latch/FAIL/Congratulations` 當名稱。

## 2. 拆成 4 個步驟（每步對應 OISS.v 一段）
1. **解碼**：切出 op/rs/rt/rd、latency；用 opcode 判斷 ReadSet/WriteSet
   - 寫 rd：op 0~4（ADD SUB MUL DIV LOAD）
   - 讀 rs、rt：op 0~3 與 BRANCH(6)
   - 讀 rd：STORE(5)；JUMP 不讀不寫
2. **找相依**：對每對 i<j，`pred[j][i]=1` 若 RAW(W(i)∩R(j)) 或 WAR(R(i)∩W(j)) 或 WAW。
3. **算 tail**：`tail[i] = lat[i] + max(後繼的 tail)`，從 i=7 往 0 算（邊只會從小 index 指向大 index）。
   tail = 「從這條開始到整串結束最少還要多久」，越大越該早發射（例如 MUL/DIV 鏈頭）。
4. **貪婪排程 8 輪**：維護 `T`(下一個可發射週期)、`issued`、`fin[]`。每輪：
   - 候選 = 還沒發射且前驅都已發射的指令，`ready = max(前驅 fin)`。
   - 若有 `ready<=T` 的，選 tail 最大者；否則選 `ready` 最小者（同分選 tail 大）。
   - `start=max(T,ready)`，`fin=start+lat`，`T=start+1`，把它寫進 `Inst_order_O[3k+:3]`。
   - `Ex_cycle` = 所有 fin 的最大值。

## 3. 為什麼這樣是最佳的
題目保證相依圖只有：無相依 / 一條鏈 / 兩條不相交的鏈。這時「每次挑已就緒且 tail 最長者」
（Jackson / 最長尾優先）就是最佳解。我用 C 暴力枚舉 8! 種順序驗證：
符合題目結構的 23000 筆隨機測資全部與最佳解一致（完全隨機相依圖則約 0.2% 不是最佳，但題目不會出現）。

## 4. 手刻 Verilog 時的注意事項
- `always @(*)` 內先給所有變數預設值（本檔每個 reg 都在使用前賦值），避免合成出 latch。
- 用 blocking assignment 與 `for` 迴圈展開；陣列用一維 `reg [w:0] a [0:7]`。
- `for (i=7;i>=0;i=i-1)` 的 `i` 用 `integer`（有號）。
- 寬度：週期最大 400，用 9 bit。

## 5. 如何測試
```
cd 01_RTL
# 助教的 PATTERN 沒給時，可用自製資料：
gcc -O2 -o gen ../tools/gen.c && ./gen 3000 1 2      # 產生 input.txt / output.txt（暴力最佳解）
iverilog -g2012 -o sim OISS.v TESTBED.v && vvp sim   # 預期印出 ALL ... PASS
```
`tools/gen.c` 的參數：`N seed mode`（mode 2 = 只產生符合題目相依結構的測資）。
正式 demo 時請改用助教的 `01_run_vcs_rtl` / `01_run_dc_shell`，並檢查 syn.log 無 latch、面積 < 1,500,000 µm²。
