# 電路視覺化教學助手

這個專案是一個給香港中學生學習串聯、並聯、短路與基本電路元件的教學網站。學生可以用文字或電路圖片生成 Falstad / CircuitJS 可匯入代碼，再在右側模擬器中觀察電流小圓點、電壓顏色與開關變化。

## 主要功能

- 雙語前端介面：繁體中文 / English
- Google Gemini 後端代理，API key 不會暴露在瀏覽器
- 文字需求及電路圖片上載
- `Generate Circuit`：生成 Falstad 專用代碼
- `Generate Guide`：根據已生成代碼輸出視覺化教學指引
- `Generate Tutor`：根據已生成代碼輸出引導式解題教學草稿
- `Raw AI Output`：顯示模型實際輸出與本地 compiler 結果，方便排錯
- 右側內嵌本地 Falstad / CircuitJS1 模擬器
- 雙語切換時同步切換 Falstad 面板語言
- Step 2 的 Falstad code 可直接手動修改，再載入右側模擬器

## 現時生成架構

網站已由早期的 planner / formatter 雙階段，簡化為更穩定的三段式流程：

1. Gemini 先把文字或圖片轉成「香港中學物理課程元件 schema」
2. Ruby 後端把 schema 本地編譯成 Falstad code
3. 如果 schema 失敗，後端才 fallback 到直接 Falstad code 生成

這樣做的原因是 Falstad dump code 對 AI 來說較易出錯，但香港中學課程元件較清楚：`battery`、`resistor`、`internal_resistance`、`variable_resistor`、`lamp`、`switch`、`ammeter`、`voltmeter`、`wire`。

## 專案結構

- `index.html`: 主畫面
- `styles.css`: 視覺樣式
- `app.js`: 前端互動、圖片壓縮、雙語切換、Falstad 載入、Raw AI Output 顯示
- `server.rb`: Ruby 後端代理、Gemini 呼叫、schema compiler、背景生成工作
- `server-config.local.json`: 本地開發用 API key / model / port 設定
- `serve.command`: 一鍵啟動本地 server
- `falstad/`: 右側 iframe 真正使用的 CircuitJS1 runtime
- `vendor/circuitjs1-source/`: CircuitJS1 GitHub source snapshot
- `Dockerfile`, `Gemfile`, `.dockerignore`: Render / Docker 部署用檔案

## 本地設定

請建立或編輯 `server-config.local.json`：

```json
{
  "google_api_key": "PASTE_YOUR_API_KEY_HERE",
  "google_model": "gemini-3-flash",
  "port": 8080
}
```

說明：

- `google_api_key`: 你的 Google AI Studio / Gemini API key
- `google_model`: 你要使用的模型，例如 `gemini-3-flash`
- `port`: 本地 server port，預設 `8080`

不要把真正 API key commit 到 GitHub。

## 本地啟動

方法 1：直接執行

```bash
/Users/clear/Documents/New\ project/serve.command
```

方法 2：命令列

```bash
cd "/Users/clear/Documents/New project"
ruby server.rb
```

然後開啟：

```txt
http://localhost:8080
```

不要直接雙擊 `index.html`，否則後端 API 與右側 Falstad iframe 可能不能正常運作。

## API 說明

### 開始生成

`POST /api/generate`

```json
{
  "task": "circuit",
  "promptText": "兩個電阻串聯",
  "imageDataUrl": "",
  "outputLanguage": "zh-Hant",
  "falstadCode": ""
}
```

回應：

```json
{
  "job_id": "abc123",
  "task": "circuit",
  "status": "queued"
}
```

### 查詢生成結果

`POST /api/generate`

```json
{
  "jobId": "abc123"
}
```

完成後會回傳：

```json
{
  "job_id": "abc123",
  "task": "circuit",
  "status": "completed",
  "falstad_code": "...",
  "model_used": "gemini-3-flash",
  "raw_output": "..."
}
```

`guide` 任務會回傳 `teaching_guide`，`tutor` 任務會回傳 `tutor_response`。

### 健康檢查

`GET /api/health`

用來確認服務是否啟動，以及目前載入的模型設定。

## Render 部署

1. 把整個專案推到 GitHub，但不要提交真正 API key
2. 在 Render 建立 Web Service
3. Runtime 選 `Docker`
4. 在 Render `Environment` 加入：

```txt
GOOGLE_API_KEY=你的 Gemini API key
GOOGLE_MODEL=gemini-3-flash
HOST=0.0.0.0
PORT=10000
```

5. `Manual Deploy` -> `Deploy latest commit`

如果之後改了 Render 的 API key，必須重新 deploy 才會生效。

## 穩定化措施

- 輸出 token 上限設為 `65,536`
- 電路生成主路徑改為 `課程元件 schema -> 本地 compiler -> Falstad code`
- schema 只允許香港中學常見元件，減少 AI 亂用 Falstad 低層元件
- ammeter 會編譯成 Falstad 圓形安培計
- voltmeter 會編譯成 Falstad 圓形 voltmeter / probe
- 燈泡使用 Falstad lamp 元件，不再只用普通 resistor 代替
- 圖片上載會壓縮到較高解析度，保留更多導線與儀器細節
- Gemini `503 high demand` / `UNAVAILABLE` 會自動重試
- 長時間生成改用背景 job + polling，避免 Render 或瀏覽器中途切斷
- 顯示 `Raw AI Output`，方便看到 schema、compiled code 或 fallback 原因
- 自動把字面 `\\n` 還原成真正換行，避免 Falstad 匯入失敗
- 預設不加入文字標籤、箭頭或指示線，除非使用者明確要求

## Falstad code 快速讀法

Falstad / CircuitJS 的匯入代碼是一行一個元件。每一行開頭的字母或數字代表元件類型，後面的數字通常是座標、顯示設定或元件數值。

最重要的規則：

1. 每個元件佔一行
2. 不要用逗號分隔，只用空格
3. 不要把 `\n` 當文字貼入，必須是真正換行
4. 座標用 `x y` 表示，原點在左上角
5. `x` 向右增加，`y` 向下增加
6. 本專案要求所有座標都是 `16` 的倍數，例如 `128`, `144`, `160`
7. 兩個元件要連接，端點座標必須完全相同

### 第一行設定

每個電路通常由這一行開始：

```txt
$ 1 0.000005 10.20027730826997 50 5 43
```

這一行是模擬器設定，不是電路元件。學生通常不需要修改。真正要看的，是下面每一行元件。

### 導線 `w`

格式：

```txt
w x1 y1 x2 y2 flags
```

例子：

```txt
w 128 128 224 128 0
```

意思：

- `w`: wire，即導線
- `128 128`: 導線起點
- `224 128`: 導線終點
- `0`: 預設設定，通常不用改

如要拉長導線，可以改 `x2 y2`。例如終點由 `224 128` 改成 `320 128`。

### 電池 / 電源 `v`

格式：

```txt
v x1 y1 x2 y2 flags waveform frequency voltage bias phase duty
```

例子：

```txt
v 128 128 224 128 0 0 40 9 0 0 0.5
```

意思：

- `v`: voltage source，即電池或電源
- `128 128`: 電池一端
- `224 128`: 電池另一端
- `0`: 預設顯示設定
- `0`: 直流 DC
- `40`: Falstad 預設參數，DC 電路通常不用改
- `9`: 電壓，這裡是 `9 V`
- `0 0 0.5`: 其他波形參數，DC 電路通常不用改

學生最常改的是電壓，例如把 `9` 改成 `6`。

### 電阻 `r`

格式：

```txt
r x1 y1 x2 y2 flags resistance
```

例子：

```txt
r 224 128 320 128 0 100
```

意思：

- `r`: resistor，即電阻
- `224 128`: 電阻一端
- `320 128`: 電阻另一端
- `0`: 預設設定
- `100`: 電阻值，單位是 ohm

如要把電阻改成 `50 ohm`，把最後的 `100` 改成 `50`。

### 燈泡 `181`

格式：

```txt
181 x1 y1 x2 y2 flags temperature power voltage warmup cooldown
```

例子：

```txt
181 320 128 416 128 0 300 100 120 0.4 0.4
```

意思：

- `181`: Falstad 的 lamp，即燈泡
- `320 128`: 燈泡一端
- `416 128`: 燈泡另一端
- `0`: 預設設定
- `300 100 120 0.4 0.4`: 燈泡模型參數，本專案通常保持不變

學生通常只需要改燈泡位置，不需要改後面的燈泡模型參數。

### 開關 `s`

格式：

```txt
s x1 y1 x2 y2 flags position momentary
```

例子：

```txt
s 224 128 320 128 0 1 false
```

意思：

- `s`: switch，即開關
- `224 128`: 開關一端
- `320 128`: 開關另一端
- `0`: 預設設定
- `1`: 開關打開，即 open
- `false`: 不是按鈕式瞬時開關

如想令開關閉合，把 `1` 改成 `0`。

### 安培計 `370`

格式：

```txt
370 x1 y1 x2 y2 flags value
```

例子：

```txt
370 224 128 320 128 3 0
```

意思：

- `370`: Falstad 的 ammeter，即安培計
- `224 128`: 安培計一端
- `320 128`: 安培計另一端
- `3`: 顯示讀數和圓形儀表符號
- `0`: 預設值，通常不用改

安培計應該串聯接入電路中。

### 伏特計 `p`

格式：

```txt
p x1 y1 x2 y2 flags value resistance
```

例子：

```txt
p 320 192 416 192 3 0 10000000
```

意思：

- `p`: probe / voltmeter，即伏特計或電壓探針
- `320 192`: 伏特計一端
- `416 192`: 伏特計另一端
- `3`: 顯示讀數和圓形儀表符號
- `0`: 預設值，通常不用改
- `10000000`: 極高電阻，用來模擬理想伏特計

伏特計應該並聯接在要量度的元件兩端。

### 可變電阻 `174`

格式：

```txt
174 x1 y1 x2_or_wiper_x y2_or_wiper_y flags max_resistance position label
```

例子：

```txt
174 224 128 320 192 1 1000 0.5 Resistance
```

意思：

- `174`: Falstad 的可調電阻 / potentiometer 類元件
- `224 128`: 元件其中一端
- `320 192`: 滑動端或控制點位置
- `1`: 預設設定
- `1000`: 最大電阻值
- `0.5`: 滑動位置，約在中間
- `Resistance`: 控制滑桿名稱

學生最常改的是 `1000` 和 `0.5`。`position` 建議保持在 `0.05` 至 `0.95` 之間。

### 文字標籤 `x`

格式：

```txt
x x1 y1 x2 y2 flags size text
```

例子：

```txt
x 360 96 376 96 4 20 X
```

意思：

- `x`: text label，即文字標籤
- `360 96`: 文字位置
- `376 96`: Falstad 內部用的第二座標
- `4`: 文字顯示設定
- `20`: 字體大小
- `X`: 顯示文字

本專案預設不會加入太多文字標籤，避免 AI 標錯位置。只有原圖或需求明確標示 `X`, `Y`, `Z`, `A`, `V`, `R1` 等名稱時才建議加入。

### 修改 code 的安全方法

學生可以安全嘗試：

1. 改電池電壓：在 `v` 行改電壓數字，例如 `9` 改成 `6`
2. 改電阻值：在 `r` 行改最後一個數字，例如 `100` 改成 `200`
3. 開關開合：在 `s` 行把 `1` 和 `0` 互換
4. 移動元件：同時改元件兩端座標，但保持 `16` 的倍數
5. 加長導線：改 `w` 行的終點座標

修改時要小心：

1. 不要刪除第一行 `$ ...`
2. 不要把座標改成非 `16` 的倍數
3. 不要令本來應該相接的端點座標不一致
4. 不要隨便改 lamp、ammeter、voltmeter 後面的固定參數
5. 每次只改一兩個地方，再載入 Falstad 測試

### 簡單例子

以下是一個電池、開關和兩個串聯電阻的簡化例子：

```txt
$ 1 0.000005 10.20027730826997 50 5 43
v 128 128 128 224 0 0 40 9 0 0 0.5
s 128 128 224 128 0 0 false
r 224 128 320 128 0 100
r 320 128 416 128 0 100
w 416 128 416 224 0
w 416 224 128 224 0
```

可觀察：

- `v` 是電池，電壓是 `9 V`
- `s` 是開關，`0` 表示閉合
- 兩行 `r` 是兩個 `100 ohm` 電阻
- 兩行 `w` 把右邊和下方接回電池，形成完整迴路

## 真實實驗室相片建議

真實相片比課本電路圖困難，因為導線會彎曲、互相遮擋，儀器端子也可能被手或鱷魚夾擋住。為了提升 AI 辨識率，建議：

1. 從正上方或斜上方拍攝，盡量看到每個元件兩端端子
2. 保持光線充足，避免強反光、陰影和模糊
3. 讓整個電路完整入鏡，不要切走電池、開關或錶的接線端
4. 盡量把未使用的導線移開，減少背景干擾
5. 如果有 A/V 錶，讓錶面或標籤清楚可見
6. 上載相片時加一兩句文字提示，例如「紅線由電池正極接到開關，再接到燈泡 X」
7. 如果電路很複雜，先拍局部或先生成單一支路，再逐步擴展
8. 最理想是同時提供相片和手繪簡圖，AI 用相片看元件，用簡圖確認拓撲

## Raw AI Output

`Raw AI Output` 顯示模型實際給後端的可見輸出，以及後端本地處理結果。它不是模型完整內部推理過程。

常見內容包括：

- `[Circuit Schema]`: Gemini 輸出的課程元件 schema
- `[Compiled Falstad Code]`: Ruby compiler 轉出的 Falstad code
- `[Schema Fallback]`: schema 失敗時的 fallback 說明
- `[Direct Falstad Fallback]`: 直接生成 Falstad code 的模型輸出
- `[Guide]` 或 `[Tutor]`: 教學指引或解題教學草稿的原始輸出

## Chatbot 直接測試 Prompt

你可以把以下 prompt 貼到 Gemini chatbot，再上載一張電路圖或輸入文字需求，測試模型是否能先穩定輸出 schema。

```txt
你是香港中學物理電路視覺化助手。你的任務不是解題，而是把我提供的文字需求或電路圖片，轉成一個可由程式編譯成 Falstad / CircuitJS 電路的「課程元件 schema」。

嚴格限制：
1. 只輸出一個 JSON object，不要 markdown，不要解釋，不要 code fence。
2. 不要輸出 Falstad dump code。
3. 不要解題，不要使用公式，不要提供測驗答案。
4. 只可使用這些 component type：
   wire, battery, resistor, internal_resistance, variable_resistor, lamp, switch, ammeter, voltmeter
5. 所有 x1, y1, x2, y2, wiper_x, wiper_y 必須是 16 的倍數。
6. wire, resistor, lamp, switch, ammeter, voltmeter, battery, internal_resistance 必須水平或垂直。
7. 所有轉角、外框、分支都用 wire 表示。
8. 如果有燈泡，使用 type="lamp"，不要用 resistor 代替。
9. 如果有安培計，使用 type="ammeter"；如果有伏特計，使用 type="voltmeter"。
10. 如果有可變電阻或滑動變阻器，使用 type="variable_resistor"，並加入 wiper_x 和 wiper_y。
11. 只有原圖或題目明確標示 X、Y、Z、A、V、R1、S1 等名稱時，才加入 id 或 label；不要自行加入裝飾文字、箭咀、指示線。
12. 不適用的欄位請省略；例如 wire 不需要 resistance，battery 不需要 wiper_x。

如果我上載的是真實實驗室相片：
1. 先把實物連接轉成乾淨電路圖。
2. 只追蹤真正連接的端子與導線，忽略桌面、手、陰影、未接上的鬆散導線和背景物件。
3. 電池盒或電源供應器視為 battery；燈座/燈泡視為 lamp；鱷魚夾導線視為 wire；滑動變阻器/變阻器視為 variable_resistor；A/V 錶視為 ammeter/voltmeter；開關掣視為 switch。
4. 導線如彎曲或凌亂，不要複製實物形狀；只保留拓撲，用水平或垂直線連接相同端點。
5. 如果某部分不清楚，請在 summary 簡短說明不確定之處，但仍輸出你最合理的有效 schema。

輸出 JSON 格式：
{
  "summary": "用一句話描述電路拓撲，不要解題",
  "components": [
    {
      "id": "可選，例如 X",
      "label": "可選，例如 X",
      "type": "wire",
      "x1": 128,
      "y1": 128,
      "x2": 256,
      "y2": 128,
      "wiper_x": 192,
      "wiper_y": 192,
      "voltage": 9,
      "resistance": 100,
      "max_resistance": 1000,
      "position": 0.5,
      "state": "open"
    }
  ]
}

現在請根據我接下來提供的文字或圖片輸出 schema。
```

## 之後可考慮的升級方向

1. 加入圖片標註模式，讓學生點選電池、開關、燈泡和分岔點
2. 加入後端快取，避免相同 prompt 重複花 token
3. 加入生成紀錄與教師題庫
4. 加入 Falstad code 驗證器
5. 加入學生操作紀錄與學習歷程
