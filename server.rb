require "json"
require "open3"
require "openssl"
require "pathname"
require "timeout"
require "uri"
require "webrick"
require "net/http"

ROOT = Pathname.new(__dir__)
CONFIG_PATH = ROOT.join("server-config.local.json")
GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
MAX_OUTPUT_TOKENS = 6144
COMPACT_MAX_OUTPUT_TOKENS = 4096
CURL_RETRY_ATTEMPTS = 3

SYSTEM_PROMPT = <<~PROMPT
  你是香港中學科學與物理的「電路視覺化教學輔助專家」。
  目標：把圖片或文字需求轉成 Falstad 專用代碼，並提供只聚焦於操作與觀察的教學指引。

  禁令：
  1. 不可解題。
  2. 不可使用物理公式計算。
  3. 不可直接提供最終答案。

  請只輸出 JSON，格式必須是：
  {
    "analysis": "第 1 部分內容",
    "falstad_code": "第 2 部分內容",
    "teaching_guide": "第 3 部分內容"
  }

  欄位要求：
  - analysis：客觀描述電路拓撲；若是文字需求，簡述如何轉成電路佈局；指出串聯、並聯、短路或陷阱；不可直接道破答案。
  - falstad_code：輸出可匯入 Falstad 的純文字代碼；所有 X/Y 座標必須是 16 的倍數；多個電路要整齊排列在同一畫布並用文字標籤；電池用 6V 或 9V；理想安培計視為導線加 A 標籤；理想伏特計視為 1e9 歐姆加 V 標籤；負載使用 r 或 181。
  - teaching_guide：只寫如何操作 Falstad 與引導學生觀察什麼；串聯要提示單一路徑與綠色電壓像下樓梯變暗；並聯要提示找分岔點與各分支頂部保持鮮綠；加入 3 至 6 點具體操作建議。

  請保持精簡、可直接教學使用。除了 JSON 之外，不要輸出任何文字。
PROMPT

def load_config
  defaults = {
    "google_api_key" => ENV["GEMINI_API_KEY"] || ENV["GOOGLE_API_KEY"],
    "google_model" => ENV.fetch("GOOGLE_MODEL", "gemini-2.5-flash-lite"),
    "port" => ENV.fetch("PORT", "8080").to_i
  }

  return defaults unless CONFIG_PATH.exist?

  file_config = JSON.parse(CONFIG_PATH.read)
  defaults.merge(file_config)
end

def parse_data_url(data_url)
  match = data_url.match(%r{\Adata:(?<mime>[-\w.+/]+);base64,(?<data>.+)\z})
  return nil unless match

  {
    "mime_type" => match[:mime],
    "data" => match[:data]
  }
end

def build_gemini_payload(prompt_text, image_data_url, compact: false)
  prompt_body = [
    SYSTEM_PROMPT,
    "",
    "請根據以下需求產生教學用 Falstad 內容。",
    compact ? "請輸出更精簡的版本，每個欄位只保留教學必需內容。" : "請保持精簡，避免冗長說明。",
    "",
    "【使用者文字需求】",
    prompt_text.to_s.empty? ? "使用者只上載了圖片，沒有提供文字說明。" : prompt_text
  ].join("\n")

  parts = [
    {
      "text" => prompt_body
    }
  ]

  if image_data_url && !image_data_url.empty?
    inline_data = parse_data_url(image_data_url)
    raise "圖片格式無法解析，請重新上載。" unless inline_data

    parts << {
      "inline_data" => inline_data
    }
  end

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => parts
      }
    ],
    "generationConfig" => {
      "responseMimeType" => "application/json",
      "responseSchema" => {
        "type" => "object",
        "properties" => {
          "analysis" => { "type" => "string" },
          "falstad_code" => { "type" => "string" },
          "teaching_guide" => { "type" => "string" }
        },
        "required" => ["analysis", "falstad_code", "teaching_guide"],
        "propertyOrdering" => ["analysis", "falstad_code", "teaching_guide"]
      },
      "temperature" => 0.2,
      "maxOutputTokens" => compact ? COMPACT_MAX_OUTPUT_TOKENS : MAX_OUTPUT_TOKENS
    }
  }
end

def build_json_repair_payload(raw_text)
  {
    "contents" => [
      {
        "role" => "user",
        "parts" => [
          {
            "text" => [
              "請把以下內容重整為有效 JSON。",
              "只可輸出 JSON，不可加 markdown 或其他說明。",
              "欄位必須是 analysis、falstad_code、teaching_guide。",
              "",
              "【原始內容】",
              raw_text
            ].join("\n")
          }
        ]
      }
    ],
    "generationConfig" => {
      "responseMimeType" => "application/json",
      "responseSchema" => {
        "type" => "object",
        "properties" => {
          "analysis" => { "type" => "string" },
          "falstad_code" => { "type" => "string" },
          "teaching_guide" => { "type" => "string" }
        },
        "required" => ["analysis", "falstad_code", "teaching_guide"],
        "propertyOrdering" => ["analysis", "falstad_code", "teaching_guide"]
      },
      "temperature" => 0,
      "maxOutputTokens" => 1024
    }
  }
end

def build_strict_json_repair_payload(raw_text)
  {
    "contents" => [
      {
        "role" => "user",
        "parts" => [
          {
            "text" => [
              "Convert the content below into strict JSON.",
              "Output only one JSON object.",
              "Required keys: analysis, falstad_code, teaching_guide.",
              "Each value must be a string.",
              "Do not use markdown fences.",
              "",
              raw_text
            ].join("\n")
          }
        ]
      }
    ],
    "generationConfig" => {
      "responseMimeType" => "application/json",
      "responseSchema" => {
        "type" => "object",
        "properties" => {
          "analysis" => { "type" => "string" },
          "falstad_code" => { "type" => "string" },
          "teaching_guide" => { "type" => "string" }
        },
        "required" => ["analysis", "falstad_code", "teaching_guide"],
        "propertyOrdering" => ["analysis", "falstad_code", "teaching_guide"]
      },
      "temperature" => 0,
      "maxOutputTokens" => 768
    }
  }
end

def extract_output_text(data)
  fragments = []
  Array(data["candidates"]).each do |candidate|
    Array(candidate.dig("content", "parts")).each do |part|
      text = part["text"]
      fragments << text if text.is_a?(String) && !text.strip.empty?
    end
  end

  fragments.join("\n")
end

def build_raw_output(text, upstream_data = nil)
  raw_text = text.to_s.strip
  return raw_text unless raw_text.empty?
  return "" unless upstream_data

  JSON.pretty_generate(upstream_data)
rescue StandardError
  upstream_data.to_s
end

def truncated_json_output?(text)
  normalized = normalize_model_text(text)
  return false if normalized.empty?
  return false unless normalized.start_with?("{")

  !normalized.end_with?("}") || extract_json_candidate(normalized).nil?
end

def response_truncated?(data)
  finish_reasons = Array(data["candidates"]).filter_map { |candidate| candidate["finishReason"] }
  return true if finish_reasons.include?("MAX_TOKENS")

  truncated_json_output?(extract_output_text(data))
end

def normalize_model_text(text)
  text.to_s
    .gsub("\r\n", "\n")
    .gsub(/\A```(?:json)?\s*/i, "")
    .gsub(/\s*```\z/m, "")
    .strip
end

def extract_json_candidate(text)
  normalized = normalize_model_text(text)
  return normalized if normalized.start_with?("{") && normalized.end_with?("}")

  start_index = normalized.index("{")
  return nil unless start_index

  depth = 0
  in_string = false
  escaped = false

  normalized.chars.each_with_index do |char, index|
    next if index < start_index

    if in_string
      if escaped
        escaped = false
      elsif char == "\\"
        escaped = true
      elsif char == "\""
        in_string = false
      end
      next
    end

    case char
    when "\""
      in_string = true
    when "{"
      depth += 1
    when "}"
      depth -= 1
      if depth.zero?
        return normalized[start_index..index]
      end
    end
  end

  nil
end

def regex_extract_field(text, key)
  normalized = normalize_model_text(text)

  quoted_match = normalized.match(/["']#{Regexp.escape(key)}["']\s*:\s*"((?:\\.|[^"])*)"/m)
  return JSON.parse(%("#{quoted_match[1]}")) if quoted_match

  block_match = normalized.match(/^#{Regexp.escape(key)}\s*:\s*(.+?)(?=^\w+\s*:|\z)/mi)
  return block_match[1].strip if block_match

  nil
end

def fallback_field_parse(text)
  parsed = {
    "analysis" => regex_extract_field(text, "analysis"),
    "falstad_code" => regex_extract_field(text, "falstad_code"),
    "teaching_guide" => regex_extract_field(text, "teaching_guide")
  }

  return nil unless parsed.values.all? { |value| value.is_a?(String) && !value.strip.empty? }

  parsed
end

def ensure_required_fields(parsed)
  return nil unless parsed.is_a?(Hash)

  normalized = {}
  %w[analysis falstad_code teaching_guide].each do |key|
    value = parsed[key] || parsed[key.to_sym]
    return nil unless value.is_a?(String) && !value.strip.empty?

    normalized[key] = value.strip
  end

  normalized
end

def parse_model_json(text)
  normalized = normalize_model_text(text)
  direct = ensure_required_fields(JSON.parse(normalized)) rescue nil
  return direct if direct

  candidate = extract_json_candidate(normalized)
  from_candidate = ensure_required_fields(JSON.parse(candidate)) rescue nil
  return from_candidate if from_candidate

  from_fields = fallback_field_parse(normalized)
  return from_fields if from_fields

  raise JSON::ParserError, "Unable to parse model output as required JSON"
end

def json_response(res, status:, body:)
  res.status = status
  res["Content-Type"] = "application/json; charset=utf-8"
  res.body = JSON.generate(body)
end

def transport_error?(error)
  error.is_a?(EOFError) ||
    error.is_a?(IOError) ||
    error.is_a?(Errno::ECONNRESET) ||
    error.is_a?(Net::ReadTimeout) ||
    error.is_a?(OpenSSL::SSL::SSLError) ||
    error.is_a?(Timeout::Error)
end

def gemini_endpoint_for(model)
  URI("#{GEMINI_API_BASE}/#{model}:generateContent")
end

def request_gemini_via_net_http(payload, api_key, model)
  Timeout.timeout(60) do
    endpoint = gemini_endpoint_for(model)
    http = Net::HTTP.new(endpoint.host, endpoint.port)
    http.use_ssl = true
    http.open_timeout = 20
    http.read_timeout = 60
    http.keep_alive_timeout = 0

    upstream_req = Net::HTTP::Post.new(endpoint)
    upstream_req["x-goog-api-key"] = api_key
    upstream_req["Content-Type"] = "application/json"
    upstream_req["Connection"] = "close"
    upstream_req.body = JSON.generate(payload)

    upstream_res = http.request(upstream_req)
    [upstream_res.code.to_i, upstream_res.body]
  end
end

def request_gemini_via_curl(payload, api_key, model)
  endpoint = gemini_endpoint_for(model).to_s
  last_error = nil

  CURL_RETRY_ATTEMPTS.times do |index|
    stdout, stderr, status = Open3.capture3(
      "curl",
      "--http1.1",
      "--retry",
      "2",
      "--retry-all-errors",
      "--retry-delay",
      "1",
      "--connect-timeout",
      "20",
      "--max-time",
      "90",
      "-sS",
      "-X",
      "POST",
      endpoint,
      "-H",
      "Connection: close",
      "-H",
      "x-goog-api-key: #{api_key}",
      "-H",
      "Content-Type: application/json",
      "--data-binary",
      "@-",
      "-w",
      "\n%{http_code}",
      stdin_data: JSON.generate(payload)
    )

    if status.success?
      body, http_code = stdout.sub(/\n(\d{3})\z/, ""), stdout[/\n(\d{3})\z/, 1]
      raise "無法判斷 Google API 回應狀態。" unless http_code

      return [http_code.to_i, body]
    end

    last_error = stderr.strip.empty? ? "Google API 連線中斷。" : stderr.strip
    sleep(index + 1) if index < CURL_RETRY_ATTEMPTS - 1
  end

  raise last_error || "Google API 連線失敗。"
end

def request_gemini(payload, api_key, model)
  request_gemini_via_net_http(payload, api_key, model)
rescue StandardError => e
  raise unless transport_error?(e) || e.message.include?("end of file reached")

  request_gemini_via_curl(payload, api_key, model)
end

def perform_generation(payloads, api_key, preferred_model)
  last_error = nil

  payloads.each do |payload|
    begin
      status_code, body = request_gemini(payload, api_key, preferred_model)
      parsed = JSON.parse(body)
      if status_code.between?(200, 299) && response_truncated?(parsed)
        last_error = StandardError.new("AI 輸出因長度限制被截斷，已自動改用更精簡版本重試。")
        next
      end

      return [status_code, parsed, preferred_model]
    rescue StandardError => e
      last_error = e
    end
  end

  raise last_error if last_error
  raise "Google API 請求失敗。"
end

def repair_generation_json(raw_text, api_key, model)
  status_code, body = request_gemini(build_json_repair_payload(raw_text), api_key, model)
  raise "JSON 修復請求失敗。" unless status_code.between?(200, 299)

  repaired = JSON.parse(body)
  repaired_text = extract_output_text(repaired)
  raise JSON::ParserError, "JSON repair returned empty text" if repaired_text.to_s.strip.empty?

  repaired_text
rescue JSON::ParserError
  status_code, body = request_gemini(build_strict_json_repair_payload(raw_text), api_key, model)
  raise "JSON 嚴格修復請求失敗。" unless status_code.between?(200, 299)

  repaired = JSON.parse(body)
  repaired_text = extract_output_text(repaired)
  raise JSON::ParserError, "Strict JSON repair returned empty text" if repaired_text.to_s.strip.empty?

  repaired_text
end

config = load_config

server = WEBrick::HTTPServer.new(
  BindAddress: ENV.fetch("HOST", "0.0.0.0"),
  Port: config["port"],
  DocumentRoot: ROOT.to_s,
  AccessLog: [],
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO)
)

server.mount(
  "/circuit",
  WEBrick::HTTPServlet::FileHandler,
  ROOT.join("falstad").to_s
)

server.mount_proc "/api/health" do |_req, res|
  json_response(
    res,
    status: 200,
    body: {
      ok: true,
      provider: "google-gemini-api",
      has_api_key: !config["google_api_key"].to_s.empty? && config["google_api_key"] != "PASTE_YOUR_API_KEY_HERE",
      model: config["google_model"]
    }
  )
end

server.mount_proc "/api/generate" do |req, res|
  unless req.request_method == "POST"
    json_response(res, status: 405, body: { error: "Method not allowed" })
    next
  end

  api_key = config["google_api_key"].to_s
  if api_key.empty? || api_key == "PASTE_YOUR_API_KEY_HERE"
    json_response(res, status: 500, body: { error: "請先在 server-config.local.json 填入 Google AI Studio / Gemini API key。" })
    next
  end

  begin
    request_body = JSON.parse(req.body)
    prompt_text = request_body["promptText"].to_s.strip
    image_data_url = request_body["imageDataUrl"].to_s.strip
    raw_output = ""

    if prompt_text.empty? && image_data_url.empty?
      json_response(res, status: 400, body: { error: "請提供文字需求或圖片。" })
      next
    end

    payloads = [
      build_gemini_payload(prompt_text, image_data_url, compact: false),
      build_gemini_payload(prompt_text, image_data_url, compact: true)
    ]
    status_code, upstream_data, model_used = perform_generation(payloads, api_key, config["google_model"])

    unless status_code.between?(200, 299)
      error_message = upstream_data.dig("error", "message") || JSON.generate(upstream_data)
      json_response(
        res,
        status: status_code,
        body: {
          error: error_message,
          model_used: model_used,
          raw_output: build_raw_output("", upstream_data)
        }
      )
      next
    end

    raw_text = extract_output_text(upstream_data)
    raw_output = build_raw_output(raw_text, upstream_data)
    raise "AI 沒有回傳文字內容，請再試一次。" if raw_text.to_s.strip.empty?

    begin
      parsed = parse_model_json(raw_text)
    rescue JSON::ParserError
      repaired_text = repair_generation_json(raw_text, api_key, model_used)
      parsed = parse_model_json(repaired_text)
    end

    parsed["model_used"] = model_used
    parsed["raw_output"] = raw_output
    json_response(res, status: 200, body: parsed)
  rescue JSON::ParserError
    json_response(
      res,
      status: 502,
      body: {
        error: "AI 回應不是有效 JSON，請再按一次 Generate。",
        raw_output: raw_output
      }
    )
  rescue StandardError => e
    json_response(
      res,
      status: 500,
      body: {
        error: e.message,
        raw_output: raw_output
      }
    )
  end
end

trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }

puts "Serving Circuit Visualizer at http://localhost:#{config["port"]}"
server.start
