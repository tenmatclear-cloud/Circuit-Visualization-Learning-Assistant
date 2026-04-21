# 電路視覺化教學助手

這個專案是一個給學生學習串聯、並聯與短路概念的教學網站，結合了：

- 雙語前端介面：繁體中文 / English
- Google Gemini 後端代理
- 本地或線上部署的 Falstad Circuit Simulator
- `Raw AI Output` 偵錯視窗

學生可用文字或電路圖圖片生成：

- Falstad 專用代碼
- 視覺化教學指引

然後直接載入右側 Falstad 模擬器觀察電流與電壓變化。

## 主要功能

- 文字需求輸入
- 電路圖圖片上載
- Gemini API 後端代理，不把 API key 暴露在前端
- Falstad 專用代碼輸出
- 視覺化教學指引輸出
- `Raw AI Output` 顯示模型原始回覆，方便排錯
- 自動把字面 `\\n` 還原成真正換行，避免 Falstad 匯入失敗
- 偵測 Gemini 輸出截斷後自動重試更精簡版本
- 右側內嵌 Falstad 模擬器
- 雙語切換時同步切換 Falstad 面板語言

## 專案結構

- `index.html`: 主畫面
- `styles.css`: 視覺樣式
- `app.js`: 前端互動、雙語切換、Falstad 載入、Raw AI Output 顯示
- `server.rb`: Ruby 後端代理，呼叫 Gemini API 並整理輸出
- `server-config.local.json`: 本地開發用 API key / model / port 設定
- `serve.command`: 一鍵啟動本地 server
- `falstad/`: 可直接運行的 CircuitJS1 runtime
- `vendor/circuitjs1-source/`: CircuitJS1 GitHub source snapshot
- `Dockerfile`, `Gemfile`, `.dockerignore`: Render / Docker 部署用檔案

## 運作流程

1. 學生在左側輸入文字需求或上載圖片
2. 前端把資料送到 `POST /api/generate`
3. `server.rb` 會先要求 Gemini 產生「香港中學物理元件 schema」
4. 後端把 schema 本地編譯成 Falstad 專用代碼；如果 schema 路徑失敗，會自動 fallback 到直接 Falstad 生成
5. guide / tutor 任務則以現有 Falstad 代碼為基礎生成
6. 後端回傳：
   - `falstad_code`
   - `teaching_guide` 或 `tutor_response`
   - `raw_output`
7. 前端把 Falstad 代碼、教學指引 / 解題教學與 Raw AI Output 顯示出來
8. 學生可直接按 `載入右側模擬器` 匯入 Falstad

## 本地設定

請編輯：

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

## 本地啟動

### 方法 1：直接執行

```bash
/Users/clear/Documents/New\ project/serve.command
```

### 方法 2：命令列

```bash
cd "/Users/clear/Documents/New project"
ruby server.rb
```

開啟：

```txt
http://localhost:8080
```

## API 說明

### `POST /api/generate`

Request body:

```json
{
  "promptText": "兩個電阻串聯",
  "imageDataUrl": ""
}
```

Response body:

```json
{
  "analysis": "...",
  "falstad_code": "...",
  "teaching_guide": "...",
  "raw_output": "...",
  "model_used": "gemini-3-flash"
}
```

其中 `raw_output` 目前會同時顯示：

- `Planner`
- `Formatter`

方便觀察兩階段生成的實際輸出。

### `GET /api/health`

用來確認服務是否啟動，以及目前載入的模型設定。

## Render 部署

### 1. 推到 GitHub

把整個專案推到 GitHub，但不要把真正的 API key 提交到 repo。

### 2. 在 Render 建立 Web Service

- Source: 你的 GitHub repo
- Runtime: `Docker`

### 3. 在 Render 設定環境變數

```txt
GOOGLE_API_KEY=你的 Gemini API key
GOOGLE_MODEL=gemini-3-flash
HOST=0.0.0.0
PORT=10000
```

### 4. Deploy

部署完成後，Render 會提供公開網址。

## Falstad 整合方式

此專案保留兩部分：

### 可執行 runtime

放在：

```txt
falstad/
```

這是右側 iframe 真正使用的版本。

### GitHub 原始碼快照

放在：

```txt
vendor/circuitjs1-source/
```

這份是方便研究 CircuitJS1 原始碼，不是目前頁面直接執行的 runtime。

## 目前已加入的穩定化措施

- `Generate Circuit` 主路徑改為：`課程元件 schema -> 本地 compiler -> Falstad code`
- schema 只使用課程元件語言：`battery / resistor / internal_resistance / variable_resistor / lamp / switch / ammeter / voltmeter / wire`
- 使用 JSON schema 約束 Gemini 先輸出結構化元件資料，而不是直接猜 Falstad dump type
- 如果 schema 路徑失敗，後端會自動 fallback 到直接 Falstad 生成
- 若 Gemini API 回傳 `503 high demand` / `UNAVAILABLE`，後端會自動重試
- 若回應被截斷，會自動改用 compact / minimal 版本重試
- 若回應不是標準 JSON，會做修復嘗試
- 顯示 `Raw AI Output`，方便觀察模型真實輸出
- 自動把 `falstad_code` 中的字面 `\\n` 還原成真正換行
- 預設不加入文字標籤、箭頭或指示線，除非使用者明確要求

## 常見問題

### 1. `The AI response was not valid JSON`

先看 `Raw AI Output`：

- 如果是半截 JSON：通常是模型輸出被截斷
- 如果有 markdown code fence：代表模型沒完全遵守 schema
- 如果 `falstad_code` 有字面 `\\n`：新版前後端會自動還原

### 1a. `This model is currently experiencing high demand`

這通常不是 token 限制，而是 Gemini 服務端暫時繁忙。

新版後端會自動重試幾次。如果仍然失敗，可：

1. 稍後再試
2. 改用更簡單的 prompt
3. 減少一次生成的電路數量

### 1b. `AI 回應過長`

如果系統已經自動改用 compact / minimal 版本仍未完成，建議先：

1. 生成單一基礎電路
2. 不要一次要求多個對比圖
3. 暫時不要要求額外標示、註解或變形圖

### 2. 右側 Falstad 沒顯示

確認：

- 網址是 `http://localhost:8080`
- 不是直接雙擊 `index.html`
- `falstad/circuitjs.html` 存在

### 3. Render 改了 API key 但沒生效

修改完 Render `Environment` 後，請再：

1. `Manual Deploy`
2. `Deploy latest commit`

## 關於 Raw AI Output

`Raw AI Output` 顯示的是模型實際給我們的可見輸出，不是模型的完整內部推理過程。

這樣設計的好處是：

- 省 token
- 減少暴露不必要的冗長內容
- 更容易把結果穩定限制在 JSON / Falstad code / guide

目前後端已採用這個提升穩定度的做法：

1. 第一步讓模型先做較自由的草稿規劃
2. 第二步再把草稿轉成嚴格 JSON

這樣的設計重點不是讓 AI 直接講 Falstad 內部語言，而是先讓它講比較接近香港中學課程的元件語言，再交給本地 compiler 處理 Falstad 的怪格式。

## 之後可考慮的升級方向

1. 加入後端快取，避免相同 prompt 重複花 token
2. 加入生成紀錄與教師題庫
3. 擴充課程元件 schema，例如加入 `cell pack`、`fuse`、`motor`
4. 為 voltmeter / ammeter 提供更接近學校圖符的本地繪製策略
5. 加入 Falstad 代碼驗證器
6. 加入學生操作紀錄

## 來源

- CircuitJS1 GitHub:
  - <https://github.com/sharpie7/circuitjs1>
- Falstad 官方：
  - <https://www.falstad.com/circuit/about.html>
- Google Gemini API docs：
  - <https://ai.google.dev/gemini-api/docs>
