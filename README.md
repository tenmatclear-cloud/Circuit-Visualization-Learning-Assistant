# 電路視覺化教學助手

這個專案現在是「前端 + 本地後端代理 + 本地 Falstad simulator」版本。

學生流程如下：

1. 在左側輸入文字需求，或上載電路圖圖片。
2. 前端把資料送到本地後端 `/api/generate`。
3. 後端代你呼叫 Google Gemini API，回傳：
   - Falstad 專用代碼
   - Falstad 視覺化教學指引
4. 學生可直接把代碼載入右側本地 Falstad simulator 觀察。

## 現在的檔案結構

- `index.html`: 主畫面
- `styles.css`: 樣式
- `app.js`: 前端互動，呼叫本地 `/api/generate`
- `server.rb`: Ruby 本地伺服器與 Google Gemini API 後端代理
- `server-config.local.json`: 本地 Gemini / Gemma API key 與模型設定
- `serve.command`: 一鍵啟動伺服器
- `falstad/`: 可直接運行的 CircuitJS1 靜態 runtime
- `vendor/circuitjs1-source/`: GitHub 原始碼快照

## 後端代理版本怎樣運作

### 前端

前端不再直接持有 API key。瀏覽器只會送：

- `promptText`
- `imageDataUrl`

到本地：

```txt
POST /api/generate
```

### 後端

`server.rb` 會：

1. 讀取 `server-config.local.json`
2. 組合你的教學 prompt
3. 呼叫 Google Gemini API
4. 把模型輸出的 JSON 整理後回傳給前端

這樣做的好處是：

- API key 不會暴露在前端 JavaScript
- 之後若要加使用記錄、題庫、快取，比較容易擴充

## API key 放哪裡

請編輯：

```txt
server-config.local.json
```

內容如下：

```json
{
  "google_api_key": "PASTE_YOUR_API_KEY_HERE",
  "google_model": "gemini-2.5-flash-lite",
  "port": 8080
}
```

如果你想走較快、較省資源的模型，建議先用：

- `gemini-2.5-flash-lite`

如之後你想切回其他 Gemini / Gemma hosted model，再改 `google_model` 即可。

## 如何啟動

### 最簡單方式

直接執行：

```bash
/Users/clear/Documents/New\ project/serve.command
```

### 或用命令列

```bash
cd "/Users/clear/Documents/New project"
ruby server.rb
```

啟動後打開：

```txt
http://localhost:8080
```

## 如何放上網

我建議你先用 Render 部署，對這個專案來說最省事。原因是：

- 這個網站不是純靜態頁，有 Ruby 後端代理
- Render 可直接部署 Web Service
- Render 支援從專案內的 Dockerfile 建置
- Render 會提供公開網址，之後也可加自訂網域與 HTTPS

### 我已經幫你準備好的部署檔

- `Dockerfile`
- `.dockerignore`
- `Gemfile`

這表示你不需要另外改專案結構，就可以直接上傳部署。

### Render 部署步驟

1. 把這個專案推到 GitHub。
2. 到 Render 建立一個新的 Web Service。
3. 連接你的 GitHub repo。
4. 在建立服務時：
   - Language / Runtime：選 `Docker`
   - Branch：選你的主分支
5. 在 Environment Variables 內加入：

```txt
GOOGLE_API_KEY=你的新 API key
GOOGLE_MODEL=gemini-3-flash-preview
PORT=10000
HOST=0.0.0.0
```

6. 按 Deploy。
7. 部署完成後，Render 會給你一個公開網址，像是：

```txt
https://your-app-name.onrender.com
```

### 自訂網域

如果你有自己的 domain，可以在 Render 後台替這個 Web Service 加上 custom domain，然後照 Render 提示設定 DNS。

### 注意事項

- 不要把真正的 API key 寫進 `server-config.local.json` 後提交到 GitHub。
- 你本地可繼續用 `server-config.local.json`，但線上環境應改用 Render 的環境變數。
- 右側 Falstad 已經是本地靜態檔，會隨專案一起部署，不需要另外裝服務。

## Falstad 是怎樣接進專案的

這次我把 Falstad 分成兩部分放入專案，這樣比較實際，也比較容易維護。

### 1. 可執行 runtime

放在：

```txt
falstad/
```

這裡使用的是 CircuitJS1 官方離線版中的：

```txt
resources/app/war
```

原因是：

- GitHub 原始碼 repo 內的 `war/` 只有頁面骨架
- 真正可直接執行的編譯輸出，例如 `circuitjs1/circuitjs1.nocache.js`，是在離線版內
- 這台機器目前沒有 Java / GWT 編譯環境，所以無法直接從 source repo 本地編譯出 runtime

因此，右側 iframe 現在會直接使用本地：

```txt
falstad/circuitjs.html
```

### 2. GitHub 原始碼快照

放在：

```txt
vendor/circuitjs1-source/
```

這裡保留的是 GitHub 開源原始碼，方便你：

- 查看專案結構
- 日後研究 CircuitJS1 原始碼
- 之後若你安裝好 Java / GWT，再自行編譯更新 runtime

## 為甚麼 source 和 runtime 要分開

因為 CircuitJS1 的 GitHub repo 並不是「下載就能直接用」的純靜態網站。

GitHub source 內的 `war/circuitjs.html` 會引用：

```txt
circuitjs1/circuitjs1.nocache.js
```

但這些編譯後的檔案不在原始碼 zip 內，而是在官方離線版的 `resources/app/war` 裡。

所以目前最穩定的做法是：

- `vendor/circuitjs1-source/` 保存 source
- `falstad/` 放真正可運行的 build

## 目前已支援的功能

- 文字需求輸入
- 圖片上載
- 本地後端代理 Google Gemini API
- Falstad 專用代碼輸出
- 視覺化教學指引輸出
- 一鍵複製結果
- 一鍵把代碼載入右側 Falstad
- 從右側 Falstad 匯出目前電路

## 本地驗證建議

啟動後建議依序檢查：

1. 首頁能正常打開
2. 右側 Falstad simulator 正常出現
3. 點 `載入示例`
4. 填入 API key 後按 `Generate`
5. 確認左側兩個輸出框出現內容
6. 按 `載入右側模擬器`

## 之後可繼續升級的方向

1. 改成正式後端框架，例如 Node/Express 或 Rails
2. 加入學生歷程與題庫
3. 加入教師模式
4. 支援多張變形電路圖批次生成
5. 在後端加入輸出驗證，例如檢查座標是否全為 16 的倍數

## 來源

- CircuitJS1 GitHub 開源原始碼：
  - <https://github.com/sharpie7/circuitjs1>
- Falstad 官方頁面：
  - <https://www.falstad.com/circuit/about.html>
- Google Gemini API：
  - <https://ai.google.dev/gemini-api/docs>
