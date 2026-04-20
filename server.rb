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
MINIMAL_MAX_OUTPUT_TOKENS = 2048
PLANNER_MAX_OUTPUT_TOKENS = 2048
PLANNER_COMPACT_MAX_OUTPUT_TOKENS = 1024
PLANNER_MINIMAL_MAX_OUTPUT_TOKENS = 512
CURL_RETRY_ATTEMPTS = 3
API_STATUS_RETRY_ATTEMPTS = 3

class GenerationError < StandardError
  attr_reader :raw_output, :status_code, :upstream_data

  def initialize(message, raw_output: "", status_code: nil, upstream_data: nil)
    super(message)
    @raw_output = raw_output.to_s
    @status_code = status_code
    @upstream_data = upstream_data
  end
end

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
  - falstad_code：輸出可匯入 Falstad 的純文字代碼；所有 X/Y 座標必須是 16 的倍數；多個電路要整齊排列在同一畫布；除非使用者明確要求，否則不要加入任何文字標籤、箭頭、指示線或額外裝飾；電池用 6V 或 9V；理想安培計視為導線加 A 標籤；理想伏特計視為 1e9 歐姆加 V 標籤；負載使用 r 或 181。
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

def json_schema
  {
    "type" => "object",
    "properties" => {
      "analysis" => { "type" => "string" },
      "falstad_code" => { "type" => "string" },
      "teaching_guide" => { "type" => "string" }
    },
    "required" => ["analysis", "falstad_code", "teaching_guide"],
    "propertyOrdering" => ["analysis", "falstad_code", "teaching_guide"]
  }
end

def user_request_label(prompt_text, output_language)
  return prompt_text unless prompt_text.to_s.empty?

  output_language.to_s == "en" ? "The user uploaded an image without additional text instructions." : "使用者只上載了圖片，沒有提供文字說明。"
end

def image_follow_up_request(output_language)
  output_language.to_s == "en" ? "The circuit image has already been interpreted in the planner above. Continue from that planner output." : "電路圖片已在前一輪 planner 解析，請根據該 planner 結果繼續。"
end

def normalized_output_language(output_language)
  case output_language.to_s
  when "en"
    "English"
  else
    "繁體中文"
  end
end

def output_language_instruction(output_language)
  language_name = normalized_output_language(output_language)
  [
    "【輸出語言】",
    "analysis 與 teaching_guide 必須使用#{language_name}輸出。",
    "falstad_code 必須保持為 Falstad 專用代碼，不需翻譯。"
  ].join("\n")
end

def build_request_parts(prompt_text, image_data_url, instruction_text, output_language, include_system_prompt: true, include_request_label: true)
  text_sections = []
  text_sections << SYSTEM_PROMPT if include_system_prompt
  text_sections << instruction_text
  text_sections << output_language_instruction(output_language)

  if include_request_label
    text_sections << "【使用者文字需求】"
    text_sections << user_request_label(prompt_text, output_language)
  end

  parts = [
    {
      "text" => text_sections.join("\n\n")
    }
  ]

  if image_data_url && !image_data_url.empty?
    inline_data = parse_data_url(image_data_url)
    raise "圖片格式無法解析，請重新上載。" unless inline_data

    parts << {
      "inline_data" => inline_data
    }
  end

  parts
end

def thinking_config_for(model, level)
  return nil unless model.to_s.start_with?("gemini-3")

  normalized_level =
    if model.to_s.include?("flash")
      %w[minimal low medium high].include?(level) ? level : "high"
    else
      %w[low high].include?(level) ? level : "high"
    end

  {
    "thinkingConfig" => {
      "thinkingLevel" => normalized_level
    }
  }
end

def build_generation_config(model, max_tokens:, temperature:, response_mime_type: nil, response_schema: nil, thinking_level: nil)
  config = {
    "temperature" => temperature,
    "maxOutputTokens" => max_tokens
  }

  config["responseMimeType"] = response_mime_type if response_mime_type
  config["responseSchema"] = response_schema if response_schema

  thinking_config = thinking_config_for(model, thinking_level)
  config.merge!(thinking_config) if thinking_config

  config
end

def build_planner_payload(prompt_text, image_data_url, output_language, model, compact: false, minimal: false)
  instruction_text = [
    "先進行隱藏規劃，暫時不要輸出最終 JSON。",
    if minimal
      "請輸出超精簡規劃，總長度盡量控制在 8 行內。"
    elsif compact
      "請輸出精簡規劃。"
    else
      "請輸出完整但精簡的規劃。"
    end,
    if minimal
      "請只列出四行：Topology / Layout / Strategy / Focus。"
    else
      "請用純文字，分成四部分："
    end,
    ("1. Topology" unless minimal),
    ("2. Layout Plan" unless minimal),
    ("3. Falstad Strategy" unless minimal),
    ("4. Teaching Focus" unless minimal),
    "要點包括：串聯/並聯/短路判斷、元件與節點安排、16 倍數座標策略、學生觀察重點。",
    "除非使用者明確要求，否則規劃中不要加入文字標籤、箭頭、指示線或指向電路某點的輔助圖形。",
    "不要直接解題，不要使用 markdown code fence，不要輸出最終 JSON。"
  ].compact.join("\n")

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_request_parts(prompt_text, image_data_url, instruction_text, output_language)
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: if minimal
                    PLANNER_MINIMAL_MAX_OUTPUT_TOKENS
                  elsif compact
                    PLANNER_COMPACT_MAX_OUTPUT_TOKENS
                  else
                    PLANNER_MAX_OUTPUT_TOKENS
                  end,
      temperature: 0.2,
      thinking_level: minimal ? "medium" : "high"
    )
  }
end

def build_image_digest_payload(image_data_url, output_language, model)
  instruction_text = [
    "請先把這張電路圖轉成簡短文字摘要，供後續 Falstad 生成使用。",
    "只輸出純文字，不要 JSON，不要 markdown，不要 code fence。",
    "請用最多 3 行，依次概括：元件、連接拓撲、特別條件（如電池、開關、短路、儀表）。",
    "摘要要足夠完整，讓後續步驟不必再看圖片。",
    "不可解題，不可推導答案。"
  ].join("\n")

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_request_parts("", image_data_url, instruction_text, output_language, include_system_prompt: false, include_request_label: false)
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: 384,
      temperature: 0,
      thinking_level: "low"
    )
  }
end

def planner_content_for_history(data)
  candidate = Array(data["candidates"]).find { |item| item.is_a?(Hash) && item["content"].is_a?(Hash) }
  content = candidate && candidate["content"]
  return nil unless content

  {
    "role" => content["role"] || "model",
    "parts" => Array(content["parts"])
  }
end

def build_text_field_payload(prompt_text, image_data_url, output_language, planner_content, model, field_name, compact: false)
  field_instruction =
    case field_name
    when "analysis"
      [
        "現在只輸出 analysis 內容。",
        "只輸出純文字，不要 JSON，不要 markdown，不要 code fence。",
        "內容要客觀描述電路拓撲、串聯/並聯/短路特徵與佈局概念。",
        "不可直接道破答案。",
        compact ? "請保持非常精簡。" : "請保持清晰、教學可用。"
      ]
    when "teaching_guide"
      [
        "現在只輸出 teaching_guide 內容。",
        "只輸出純文字，不要 JSON，不要 markdown，不要 code fence。",
        "只寫如何操作 Falstad 與如何引導學生觀察，不可解題。",
        compact ? "請保持非常精簡。" : "請給 3 至 6 點具體操作與觀察建議。"
      ]
    else
      raise "Unknown field: #{field_name}"
    end

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_request_parts(
          prompt_text,
          image_data_url,
          "請根據前一輪 planner 與原始需求，完成這個欄位。",
          output_language,
          include_system_prompt: false,
          include_request_label: !prompt_text.to_s.empty?
        )
      },
      planner_content,
      {
        "role" => "user",
        "parts" => [
          {
            "text" => field_instruction.join("\n")
          }
        ]
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: compact ? 768 : 1536,
      temperature: 0.1,
      thinking_level: model.to_s.include?("flash") ? "medium" : "low"
    )
  }
end

def build_falstad_code_payload(prompt_text, image_data_url, output_language, planner_content, model, emitted_code: "", compact: false, minimal: false)
  code_instruction = [
    "現在只輸出 Falstad 專用代碼。",
    "只輸出純文字代碼，不要 JSON，不要 markdown，不要 code fence。",
    "除非使用者明確要求，否則不要加入任何 x 文字標示、箭頭、指示線或額外裝飾。",
    "所有 X/Y 座標必須是 16 的倍數。",
    if minimal
      "請盡量多輸出完成的代碼行；如果仍未完成，最後一行輸出 [[CONTINUE]]；若已完成，最後一行輸出 [[END]]。"
    elsif compact
      "請使用較精簡的方式輸出代碼；如果仍未完成，最後一行輸出 [[CONTINUE]]；若已完成，最後一行輸出 [[END]]。"
    else
      "請完整輸出代碼；如果仍未完成，最後一行輸出 [[CONTINUE]]；若已完成，最後一行輸出 [[END]]。"
    end
  ]

  if emitted_code.to_s.strip.empty?
    continuation_instruction = "這是第一段代碼，請從第一行開始輸出。"
  else
    continuation_instruction = [
      "以下是已輸出的代碼，請從下一個新行開始續寫。",
      "不要重複、不要修改、不要重排任何已輸出的行。",
      "【已輸出代碼】",
      emitted_code
    ].join("\n")
  end

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_request_parts(
          prompt_text,
          image_data_url,
          "請根據前一輪 planner 與原始需求，續寫 Falstad 專用代碼。",
          output_language,
          include_system_prompt: false,
          include_request_label: !prompt_text.to_s.empty?
        )
      },
      planner_content,
      {
        "role" => "user",
        "parts" => [
          {
            "text" => (code_instruction + [continuation_instruction]).join("\n")
          }
        ]
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: if minimal
                    MINIMAL_MAX_OUTPUT_TOKENS
                  elsif compact
                    COMPACT_MAX_OUTPUT_TOKENS
                  else
                    MAX_OUTPUT_TOKENS
                  end,
      temperature: 0,
      thinking_level: minimal ? "low" : (model.to_s.include?("flash") ? "medium" : "low")
    )
  }
end

def build_formatter_payload(prompt_text, image_data_url, output_language, planner_content, model, compact: false, minimal: false)
  formatter_follow_up = [
    "請根據前一輪規劃與原始需求，現在輸出最終 JSON。",
    "只可輸出符合 schema 的單一 JSON 物件。",
    if minimal
      "請輸出超精簡版本，analysis 與 teaching_guide 只保留最關鍵內容。"
    elsif compact
      "請使用更精簡的最終版本。"
    else
      "請保持清晰與可直接教學使用。"
    end,
    "analysis 要客觀、不要直接道破答案。",
    "falstad_code 必須是可匯入 Falstad 的純文字代碼，並確保 X/Y 座標為 16 的倍數。",
    "除非使用者明確要求，否則不要加入任何 x 文字標示、箭頭、指示線或額外裝飾。",
    "teaching_guide 只寫如何操作 Falstad 與如何引導學生觀察。",
    "禁止輸出 markdown、註解、額外文字。"
  ].join("\n")

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_request_parts(
          prompt_text,
          image_data_url,
          "請根據前一輪 planner 與原始需求，現在輸出最終 JSON。",
          output_language,
          include_system_prompt: false,
          include_request_label: !prompt_text.to_s.empty?
        )
      },
      planner_content,
      {
        "role" => "user",
        "parts" => [
          {
            "text" => formatter_follow_up
          }
        ]
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: if minimal
                    MINIMAL_MAX_OUTPUT_TOKENS
                  elsif compact
                    COMPACT_MAX_OUTPUT_TOKENS
                  else
                    MAX_OUTPUT_TOKENS
                  end,
      temperature: minimal ? 0 : 0.1,
      response_mime_type: "application/json",
      response_schema: json_schema,
      thinking_level: if minimal
                        "low"
                      else
                        model.to_s.include?("flash") ? "medium" : "low"
                      end
    )
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
    "generationConfig" => build_generation_config(
      nil,
      max_tokens: 1024,
      temperature: 0,
      response_mime_type: "application/json",
      response_schema: json_schema
    )
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
    "generationConfig" => build_generation_config(
      nil,
      max_tokens: 768,
      temperature: 0,
      response_mime_type: "application/json",
      response_schema: json_schema
    )
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

def combine_raw_outputs(planner_text, formatter_text)
  sections = []
  planner = planner_text.to_s.strip
  formatter = formatter_text.to_s.strip

  sections << planner unless planner.empty?
  sections << formatter unless formatter.empty?

  sections.join("\n\n")
end

def append_named_raw_output(existing, label, content)
  segment = content.to_s.strip
  return existing if segment.empty?

  [existing.to_s.strip, "[#{label}]\n#{segment}"].reject(&:empty?).join("\n\n")
end

def strip_continuation_marker(text)
  normalized = text.to_s.gsub(/\r\n/, "\n").strip
  marker = if normalized.match?(/\[\[END\]\]\s*\z/)
             :end
           elsif normalized.match?(/\[\[CONTINUE\]\]\s*\z/)
             :continue
           else
             :unknown
           end

  cleaned = normalized.sub(/\n?\s*\[\[(?:END|CONTINUE)\]\]\s*\z/, "").strip
  [cleaned, marker]
end

def merge_code_chunks(existing, addition)
  prior_lines = existing.to_s.split("\n")
  new_lines = addition.to_s.split("\n")
  return addition.to_s if prior_lines.empty?
  return existing.to_s if new_lines.empty?

  max_overlap = [prior_lines.length, new_lines.length].min
  overlap = 0

  max_overlap.downto(1) do |size|
    if prior_lines.last(size) == new_lines.first(size)
      overlap = size
      break
    end
  end

  merged_lines = prior_lines + new_lines.drop(overlap)
  merged_lines.join("\n").strip
end

def truncation_error_message
  "AI 回應過長，系統已自動改用更精簡版本重試，但仍未完成。請把需求拆細一點，或先生成較簡單的單一電路。"
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

def normalize_model_field(value, preserve_newlines: false)
  normalized = value.to_s
  normalized = normalized.gsub("\\r\\n", "\n").gsub("\\n", "\n").gsub("\\t", "\t")
  normalized = normalized.gsub("\r\n", "\n")
  normalized = normalized.strip
  preserve_newlines ? normalized : normalized.gsub(/\n{3,}/, "\n\n")
end

def ensure_required_fields(parsed)
  return nil unless parsed.is_a?(Hash)

  normalized = {}
  %w[analysis falstad_code teaching_guide].each do |key|
    value = parsed[key] || parsed[key.to_sym]
    return nil unless value.is_a?(String) && !value.strip.empty?

    normalized[key] = normalize_model_field(value, preserve_newlines: key == "falstad_code")
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

def retryable_upstream_status?(status_code, data)
  return false unless [429, 500, 503, 504].include?(status_code.to_i)

  upstream_status = data.dig("error", "status").to_s
  upstream_status.empty? || %w[UNAVAILABLE RESOURCE_EXHAUSTED INTERNAL DEADLINE_EXCEEDED].include?(upstream_status)
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
    API_STATUS_RETRY_ATTEMPTS.times do |attempt|
      begin
        status_code, body = request_gemini(payload, api_key, preferred_model)
        parsed = JSON.parse(body)

        if status_code.between?(200, 299) && response_truncated?(parsed)
          last_error = GenerationError.new(
            truncation_error_message,
            raw_output: build_raw_output(extract_output_text(parsed), parsed),
            status_code: status_code,
            upstream_data: parsed
          )
          break
        end

        if retryable_upstream_status?(status_code, parsed) && attempt < API_STATUS_RETRY_ATTEMPTS - 1
          sleep(attempt + 1)
          next
        end

        return [status_code, parsed, preferred_model]
      rescue StandardError => e
        last_error = e
        sleep(attempt + 1) if attempt < API_STATUS_RETRY_ATTEMPTS - 1
      end
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

def generate_text_field(prompt_text, image_data_url, output_language, planner_content, api_key, model, field_name)
  downstream_image_data_url = ""
  payloads = [
    build_text_field_payload(prompt_text, downstream_image_data_url, output_language, planner_content, model, field_name, compact: false),
    build_text_field_payload(prompt_text, downstream_image_data_url, output_language, planner_content, model, field_name, compact: true)
  ]
  status_code, data, _model_used = perform_generation(payloads, api_key, model)
  raw_text = extract_output_text(data)
  [status_code, data, normalize_model_field(raw_text)]
rescue GenerationError => e
  raise GenerationError.new(
    e.message,
    raw_output: append_named_raw_output("", field_name.capitalize, e.raw_output),
    status_code: e.status_code,
    upstream_data: e.upstream_data
  )
end

def generate_falstad_code(prompt_text, image_data_url, output_language, planner_content, planner_raw_output, api_key, model)
  downstream_image_data_url = ""
  emitted_code = ""
  raw_output = planner_raw_output
  max_chunks = 6

  max_chunks.times do |index|
    payloads = [
      build_falstad_code_payload(prompt_text, downstream_image_data_url, output_language, planner_content, model, emitted_code: emitted_code, compact: false),
      build_falstad_code_payload(prompt_text, downstream_image_data_url, output_language, planner_content, model, emitted_code: emitted_code, compact: true),
      build_falstad_code_payload(prompt_text, downstream_image_data_url, output_language, planner_content, model, emitted_code: emitted_code, minimal: true)
    ]

    status_code, data, _model_used = perform_generation(payloads, api_key, model)
    return [status_code, data, emitted_code, append_named_raw_output(raw_output, "Falstad chunk #{index + 1}", build_raw_output("", data))] unless status_code.between?(200, 299)

    chunk_text = normalize_model_field(extract_output_text(data), preserve_newlines: true)
    raw_output = append_named_raw_output(raw_output, "Falstad chunk #{index + 1}", chunk_text)
    cleaned_chunk, marker = strip_continuation_marker(chunk_text)
    emitted_code = merge_code_chunks(emitted_code, cleaned_chunk)

    return [200, data, emitted_code, raw_output] if marker == :end
    next if marker == :continue && !cleaned_chunk.empty?

    return [200, data, emitted_code, raw_output] if marker == :unknown && !cleaned_chunk.empty?
    raise truncation_error_message
  end

  raise truncation_error_message
rescue GenerationError => e
  raise GenerationError.new(
    e.message,
    raw_output: append_named_raw_output(raw_output, "Falstad chunk (partial)", e.raw_output),
    status_code: e.status_code,
    upstream_data: e.upstream_data
  )
end

def generate_image_digest(image_data_url, output_language, api_key, model)
  payloads = [build_image_digest_payload(image_data_url, output_language, model)]
  status_code, data, _model_used = perform_generation(payloads, api_key, model)
  raw_text = extract_output_text(data)
  [status_code, data, normalize_model_field(raw_text)]
rescue GenerationError => e
  raise GenerationError.new(
    e.message,
    raw_output: append_named_raw_output("", "Image Digest", e.raw_output),
    status_code: e.status_code,
    upstream_data: e.upstream_data
  )
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
    output_language = request_body["outputLanguage"].to_s.strip
    raw_output = ""
    planner_raw_output = ""
    effective_prompt_text = prompt_text
    image_requested = !image_data_url.empty?
    planner_prompt_text = prompt_text
    planner_image_data_url = image_data_url

    if prompt_text.empty? && image_data_url.empty?
      json_response(res, status: 400, body: { error: "請提供文字需求或圖片。" })
      next
    end

    planner_status_code = nil
    planner_data = nil
    model_used = config["google_model"]

    begin
      planner_payloads = [
        build_planner_payload(planner_prompt_text, planner_image_data_url, output_language, config["google_model"], compact: false),
        build_planner_payload(planner_prompt_text, planner_image_data_url, output_language, config["google_model"], compact: true),
        build_planner_payload(planner_prompt_text, planner_image_data_url, output_language, config["google_model"], minimal: true)
      ]
      planner_status_code, planner_data, model_used = perform_generation(planner_payloads, api_key, config["google_model"])
    rescue GenerationError => e
      raise unless image_requested && e.message == truncation_error_message

      raw_output = append_named_raw_output(raw_output, "Planner direct attempt", e.raw_output)

      digest_status_code, digest_data, digest_text = generate_image_digest(image_data_url, output_language, api_key, config["google_model"])

      unless digest_status_code.between?(200, 299)
        digest_error = digest_data.dig("error", "message") || JSON.generate(digest_data)
        json_response(
          res,
          status: digest_status_code,
          body: {
            error: digest_error,
            model_used: config["google_model"],
            raw_output: append_named_raw_output(raw_output, "Image Digest", build_raw_output("", digest_data))
          }
        )
        next
      end

      raw_output = append_named_raw_output(raw_output, "Image Digest", digest_text)
      planner_prompt_text =
        if prompt_text.empty?
          digest_text
        else
          [prompt_text, "", "[Image digest]", digest_text].join("\n")
        end
      planner_image_data_url = ""
      planner_payloads = [
        build_planner_payload(planner_prompt_text, planner_image_data_url, output_language, config["google_model"], compact: false),
        build_planner_payload(planner_prompt_text, planner_image_data_url, output_language, config["google_model"], compact: true),
        build_planner_payload(planner_prompt_text, planner_image_data_url, output_language, config["google_model"], minimal: true)
      ]
      planner_status_code, planner_data, model_used = perform_generation(planner_payloads, api_key, config["google_model"])
    end

    unless planner_status_code.between?(200, 299)
      planner_error = planner_data.dig("error", "message") || JSON.generate(planner_data)
      json_response(
        res,
        status: planner_status_code,
        body: {
          error: planner_error,
          model_used: model_used,
          raw_output: append_named_raw_output(raw_output, "Planner", build_raw_output("", planner_data))
        }
      )
      next
    end

    planner_text = extract_output_text(planner_data)
    planner_raw_output = append_named_raw_output(raw_output, "Planner", build_raw_output(planner_text, planner_data))
    planner_content = planner_content_for_history(planner_data)
    raise "AI 規劃階段沒有回傳可用內容，請再試一次。" unless planner_content && !planner_text.to_s.strip.empty?
    effective_prompt_text = prompt_text.empty? && image_requested ? image_follow_up_request(output_language) : prompt_text
    image_data_url = ""

    analysis_status_code, analysis_data, analysis_text = generate_text_field(
      effective_prompt_text,
      image_data_url,
      output_language,
      planner_content,
      api_key,
      model_used,
      "analysis"
    )

    unless analysis_status_code.between?(200, 299)
      error_message = analysis_data.dig("error", "message") || JSON.generate(analysis_data)
      json_response(
        res,
        status: analysis_status_code,
        body: {
          error: error_message,
          model_used: model_used,
          raw_output: append_named_raw_output(planner_raw_output, "Analysis", build_raw_output("", analysis_data))
        }
      )
      next
    end

    guide_status_code, guide_data, guide_text = generate_text_field(
      effective_prompt_text,
      image_data_url,
      output_language,
      planner_content,
      api_key,
      model_used,
      "teaching_guide"
    )

    unless guide_status_code.between?(200, 299)
      error_message = guide_data.dig("error", "message") || JSON.generate(guide_data)
      json_response(
        res,
        status: guide_status_code,
        body: {
          error: error_message,
          model_used: model_used,
          raw_output: append_named_raw_output(
            append_named_raw_output(planner_raw_output, "Analysis", analysis_text),
            "Teaching Guide",
            build_raw_output("", guide_data)
          )
        }
      )
      next
    end

    status_code, upstream_data, falstad_code_text, raw_output = generate_falstad_code(
      effective_prompt_text,
      image_data_url,
      output_language,
      planner_content,
      append_named_raw_output(
        append_named_raw_output(planner_raw_output, "Analysis", analysis_text),
        "Teaching Guide",
        guide_text
      ),
      api_key,
      model_used
    )

    unless status_code.between?(200, 299)
      error_message = upstream_data.dig("error", "message") || JSON.generate(upstream_data)
      json_response(
        res,
        status: status_code,
        body: {
          error: error_message,
          model_used: model_used,
          raw_output: raw_output
        }
      )
      next
    end

    raise "AI 沒有回傳文字內容，請再試一次。" if falstad_code_text.to_s.strip.empty?

    parsed = {
      "analysis" => analysis_text,
      "falstad_code" => normalize_model_field(falstad_code_text, preserve_newlines: true),
      "teaching_guide" => guide_text
    }

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
  rescue GenerationError => e
    json_response(
      res,
      status: 500,
      body: {
        error: e.message,
        raw_output: e.raw_output.to_s.empty? ? raw_output : e.raw_output
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
