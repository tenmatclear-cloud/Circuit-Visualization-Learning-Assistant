require "json"
require "open3"
require "openssl"
require "pathname"
require "securerandom"
require "timeout"
require "uri"
require "webrick"
require "net/http"

ROOT = Pathname.new(__dir__)
CONFIG_PATH = ROOT.join("server-config.local.json")
GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"
MAX_OUTPUT_TOKENS = 65_536
COMPACT_MAX_OUTPUT_TOKENS = 65_536
MINIMAL_MAX_OUTPUT_TOKENS = 65_536
PLANNER_MAX_OUTPUT_TOKENS = 65_536
PLANNER_COMPACT_MAX_OUTPUT_TOKENS = 65_536
PLANNER_MINIMAL_MAX_OUTPUT_TOKENS = 65_536
CURL_RETRY_ATTEMPTS = 3
API_STATUS_RETRY_ATTEMPTS = 3
JOB_RETENTION_SECONDS = 3600
MAX_STORED_JOBS = 100
SUPPORTED_CIRCUIT_COMPONENT_TYPES = %w[
  wire
  battery
  resistor
  internal_resistance
  variable_resistor
  lamp
  switch
  ammeter
  voltmeter
].freeze
FALSTAD_HEADER = "$ 1 0.000005 10.20027730826997 50 5 43"

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

def circuit_component_schema
  {
    "type" => "object",
    "properties" => {
      "summary" => { "type" => "string" },
      "components" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "properties" => {
            "id" => { "type" => "string" },
            "label" => { "type" => "string" },
            "type" => { "type" => "string", "enum" => SUPPORTED_CIRCUIT_COMPONENT_TYPES },
            "x1" => { "type" => "integer" },
            "y1" => { "type" => "integer" },
            "x2" => { "type" => "integer" },
            "y2" => { "type" => "integer" },
            "wiper_x" => { "type" => "integer" },
            "wiper_y" => { "type" => "integer" },
            "voltage" => { "type" => "number" },
            "resistance" => { "type" => "number" },
            "max_resistance" => { "type" => "number" },
            "position" => { "type" => "number" },
            "state" => { "type" => "string", "enum" => %w[open closed] }
          },
          "required" => ["type", "x1", "y1", "x2", "y2"],
          "propertyOrdering" => [
            "id",
            "label",
            "type",
            "x1",
            "y1",
            "x2",
            "y2",
            "wiper_x",
            "wiper_y",
            "voltage",
            "resistance",
            "max_resistance",
            "position",
            "state"
          ]
        }
      }
    },
    "required" => ["components"],
    "propertyOrdering" => ["summary", "components"]
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

def build_task_parts(prompt_text, image_data_url, instruction_text, output_language, include_request_label: true)
  sections = [instruction_text]

  if include_request_label
    heading = output_language.to_s == "en" ? "User request" : "使用者需求"
    sections << "【#{heading}】"
    sections << user_request_label(prompt_text, output_language)
  end

  parts = [{ "text" => sections.join("\n\n") }]

  if image_data_url && !image_data_url.empty?
    inline_data = parse_data_url(image_data_url)
    raise "圖片格式無法解析，請重新上載。" unless inline_data

    parts << { "inline_data" => inline_data }
  end

  parts
end

def perform_generation_relaxed(payloads, api_key, preferred_model)
  last_error = nil

  payloads.each do |payload|
    API_STATUS_RETRY_ATTEMPTS.times do |attempt|
      begin
        status_code, body = request_gemini(payload, api_key, preferred_model)
        parsed = JSON.parse(body)

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

def build_circuit_schema_payload(prompt_text, image_data_url, output_language, model, compact: false)
  instruction_lines =
    if output_language.to_s == "en"
      [
        "Output one JSON object for a Hong Kong secondary-school circuit schema.",
        "The JSON must use only these component types: wire, battery, resistor, internal_resistance, variable_resistor, lamp, switch, ammeter, voltmeter.",
        "Use components only. Do not output raw Falstad dump lines.",
        "All coordinates must be integers and multiples of 16.",
        "Every wire, resistor, lamp, switch, ammeter, voltmeter, battery, and internal_resistance must be horizontal or vertical.",
        "Use wire components to build corners, rectangles, and branches.",
        "If the source circuit has battery internal resistance, output a battery component and a separate internal_resistance component in series.",
        "If the circuit uses a variable resistor, output type variable_resistor and include wiper_x and wiper_y.",
        "If the circuit includes an ammeter, output type ammeter. If it includes a voltmeter or scope probe, output type voltmeter.",
        "Ammeter and voltmeter should be treated as circular inline meters suitable for classroom diagrams.",
        compact ? "Prefer the simplest valid layout that preserves the topology." : "Preserve the topology faithfully and keep the layout tidy.",
        "Only include id or label when the source diagram or the request explicitly names a component, such as X, Y, Z, A, V, R1, or S1.",
        "Do not add decorative labels, arrows, or explanatory text."
      ]
    else
      [
        "請輸出一個香港中學物理電路用的 JSON schema。",
        "JSON 只可使用這些元件類型：wire、battery、resistor、internal_resistance、variable_resistor、lamp、switch、ammeter、voltmeter。",
        "請只輸出 schema，不要輸出原始 Falstad dump 代碼。",
        "所有座標都必須是整數，而且一定要是 16 的倍數。",
        "wire、resistor、lamp、switch、ammeter、voltmeter、battery、internal_resistance 都必須保持水平或垂直。",
        "所有轉角、長方形框架、分支都請用 wire 元件補齊。",
        "如果題目涉及電池內電阻，請輸出一個 battery 元件，再輸出一個與之串聯的 internal_resistance 元件。",
        "如果題目有可變電阻，請使用 type=variable_resistor，並提供 wiper_x 與 wiper_y。",
        "如果電路包含安培計，請直接使用 type=ammeter；如果包含伏特計或 scope probe，請直接使用 type=voltmeter。",
        "安培計與伏特計都應視為適合課堂圖示的圓形在線儀表。",
        compact ? "請優先使用最簡潔但仍保留拓撲的佈局。" : "請忠實保留拓撲，並保持佈局整齊。",
        "只有在原圖或文字需求明確出現 X、Y、Z、A、V、R1、S1 等名稱時，才加入 id 或 label。",
        "不要加入裝飾性標示、箭頭或解說文字。"
      ]
    end

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_task_parts(prompt_text, image_data_url, instruction_lines.join("\n"), output_language)
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: MAX_OUTPUT_TOKENS,
      temperature: 0,
      response_mime_type: "application/json",
      response_schema: circuit_component_schema,
      thinking_level: compact ? "low" : "medium"
    )
  }
end

def build_circuit_code_payload(prompt_text, image_data_url, output_language, model, emitted_code: "", compact: false)
  instruction_lines = [
    output_language.to_s == "en" ? "Your only task is to output Falstad circuit code that can be imported directly." : "你現在唯一的任務，是輸出可直接匯入 Falstad 的電路代碼。",
    output_language.to_s == "en" ? "Output only plain Falstad code. No JSON, no markdown, no explanations." : "只輸出 Falstad 純文字代碼，不要 JSON，不要 markdown，不要解釋。",
    output_language.to_s == "en" ? "Every X and Y coordinate must be a multiple of 16." : "所有 X 與 Y 座標都必須是 16 的倍數。",
    output_language.to_s == "en" ? "Use legal Falstad elements only. Use 6V or 9V batteries when needed." : "只使用合法的 Falstad 元件；如需要電池，請用 6V 或 9V。",
    output_language.to_s == "en" ? "If you use an ammeter, use Falstad ammeter code with the circular symbol enabled. If you use a voltmeter, use the circular voltmeter/probe symbol and a high resistance so it behaves like a meter in class diagrams." : "如果使用安培計，請使用帶圓形符號的 Falstad ammeter 代碼；如果使用伏特計，請使用帶圓形符號的 voltmeter/probe，並設定高電阻，使其符合課堂圖示與理想伏特計用途。",
    output_language.to_s == "en" ? "Do not add x text labels, arrows, callouts, or decorative helper lines unless the user explicitly asks for them." : "除非使用者明確要求，否則不要加入 x 文字標示、箭頭、指示線或裝飾性輔助圖形。",
    compact ? (output_language.to_s == "en" ? "Prefer the simplest valid layout that preserves the intended topology." : "請優先使用最簡潔、但仍保留原始拓撲的有效佈局。") : (output_language.to_s == "en" ? "Preserve the intended topology faithfully and keep the layout tidy." : "請忠實保留原有拓撲，並保持佈局整齊。"),
    output_language.to_s == "en" ? "If the code is not finished, end the chunk with [[CONTINUE]]. If finished, end with [[END]]." : "如果代碼尚未完成，請在最後一行輸出 [[CONTINUE]]；若已完成，請在最後一行輸出 [[END]]。"
  ]

  if emitted_code.to_s.strip.empty?
    continuation_text = output_language.to_s == "en" ? "This is the first chunk. Start from the first Falstad line." : "這是第一段代碼，請從第一行 Falstad 代碼開始輸出。"
  else
    continuation_text = [
      output_language.to_s == "en" ? "Continue from the next new line after the already emitted code." : "請從已輸出代碼的下一個新行開始續寫。",
      output_language.to_s == "en" ? "Do not repeat, revise, or reorder any line that has already been emitted." : "不要重複、不要修改、不要重排任何已輸出的行。",
      output_language.to_s == "en" ? "Already emitted Falstad code:" : "已輸出的 Falstad 代碼：",
      emitted_code
    ].join("\n")
  end

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_task_parts(prompt_text, image_data_url, (instruction_lines + [continuation_text]).join("\n"), output_language)
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: MAX_OUTPUT_TOKENS,
      temperature: 0,
      thinking_level: compact ? "low" : "medium"
    )
  }
end

def normalize_component_type(raw_type)
  case raw_type.to_s.strip.downcase
  when "wire", "w"
    "wire"
  when "battery", "cell", "voltage_source", "dc_voltage"
    "battery"
  when "resistor", "load"
    "resistor"
  when "internal_resistance", "inner_resistance", "battery_internal_resistance"
    "internal_resistance"
  when "variable_resistor", "var_resistor", "pot", "potentiometer", "rheostat"
    "variable_resistor"
  when "lamp", "bulb", "light_bulb"
    "lamp"
  when "switch", "spst_switch"
    "switch"
  when "ammeter", "current_meter"
    "ammeter"
  when "voltmeter", "voltage_meter", "probe"
    "voltmeter"
  else
    raw_type.to_s.strip.downcase
  end
end

def parse_circuit_schema_json(raw_text)
  normalized = normalize_model_text(raw_text)
  candidate = extract_json_candidate(normalized) || normalized
  parsed = JSON.parse(candidate)
  raise "AI 沒有回傳元件 schema。" unless parsed.is_a?(Hash)

  parsed
end

def integer_coordinate!(value, key)
  integer = Integer(value)
  raise "#{key} 必須是 16 的倍數。" unless (integer % 16).zero?

  integer
rescue ArgumentError, TypeError
  raise "#{key} 必須是整數。"
end

def positive_number(value, default)
  number = value.nil? ? default : value.to_f
  number.positive? ? number : default
end

def bounded_ratio(value, default = 0.5)
  number = value.nil? ? default : value.to_f
  [[number, 0.05].max, 0.95].min
end

def component_midpoint(component)
  [
    ((component["x1"] + component["x2"]) / 2.0).round,
    ((component["y1"] + component["y2"]) / 2.0).round
  ]
end

def build_text_label_line(text, x, y, size: 20)
  escaped = text.to_s.strip.gsub("\\", "\\\\\\").gsub(" ", "\\s").gsub("+", "%2B")
  "x #{x} #{y} #{x + 16} #{y} 4 #{size} #{escaped}"
end

def build_component_label_lines(component)
  label_text = component["label"].to_s.strip
  label_text = component["id"].to_s.strip if label_text.empty?

  return [] if label_text.empty?

  mid_x, mid_y = component_midpoint(component)
  if component["x1"] == component["x2"]
    [build_text_label_line(label_text, mid_x + 24, mid_y)]
  else
    [build_text_label_line(label_text, mid_x - 8, mid_y - 32)]
  end
end

def normalize_schema_component(component, index)
  raise "第 #{index + 1} 個元件不是有效物件。" unless component.is_a?(Hash)

  normalized = component.transform_keys(&:to_s)
  normalized["type"] = normalize_component_type(normalized["type"])
  raise "第 #{index + 1} 個元件缺少有效 type。" unless SUPPORTED_CIRCUIT_COMPONENT_TYPES.include?(normalized["type"])

  %w[x1 y1 x2 y2].each do |key|
    normalized[key] = integer_coordinate!(normalized[key], "元件 #{index + 1} 的 #{key}")
  end

  if normalized["type"] != "variable_resistor" && normalized["x1"] != normalized["x2"] && normalized["y1"] != normalized["y2"]
    raise "元件 #{index + 1}（#{normalized["type"]}）必須保持水平或垂直。"
  end

  if normalized["type"] == "variable_resistor"
    unless normalized["x1"] == normalized["x2"] || normalized["y1"] == normalized["y2"]
      raise "variable_resistor 的主體必須保持水平或垂直。"
    end

    if normalized["y1"] == normalized["y2"]
      normalized["wiper_x"] = integer_coordinate!(normalized["wiper_x"] || ((normalized["x1"] + normalized["x2"]) / 2), "元件 #{index + 1} 的 wiper_x")
      normalized["wiper_y"] = integer_coordinate!(normalized["wiper_y"], "元件 #{index + 1} 的 wiper_y")
    else
      normalized["wiper_x"] = integer_coordinate!(normalized["wiper_x"], "元件 #{index + 1} 的 wiper_x")
      normalized["wiper_y"] = integer_coordinate!(normalized["wiper_y"] || ((normalized["y1"] + normalized["y2"]) / 2), "元件 #{index + 1} 的 wiper_y")
    end
  end

  normalized
end

def compile_battery_line(component)
  voltage = positive_number(component["voltage"], 9)
  "v #{component["x1"]} #{component["y1"]} #{component["x2"]} #{component["y2"]} 0 0 40 #{voltage} 0 0 0.5"
end

def compile_resistor_like_line(component)
  resistance_default = component["type"] == "internal_resistance" ? 1 : 100
  resistance = positive_number(component["resistance"], resistance_default)
  "r #{component["x1"]} #{component["y1"]} #{component["x2"]} #{component["y2"]} 0 #{resistance}"
end

def compile_switch_line(component)
  state = component["state"].to_s.strip.downcase
  position = state == "open" ? 1 : 0
  "s #{component["x1"]} #{component["y1"]} #{component["x2"]} #{component["y2"]} 0 #{position} false"
end

def compile_variable_resistor_line(component)
  max_resistance = positive_number(component["max_resistance"] || component["resistance"], 1000)
  position = bounded_ratio(component["position"], 0.5)
  slider_label = component["label"].to_s.strip
  slider_label = component["id"].to_s.strip if slider_label.empty?
  slider_label = "Resistance" if slider_label.empty?
  slider_label = slider_label.gsub("\\", "\\\\\\").gsub(" ", "\\s")

  if component["y1"] == component["y2"]
    raw_x2 = component["x2"]
    raw_y2 = component["wiper_y"]
  else
    raw_x2 = component["wiper_x"]
    raw_y2 = component["y2"]
  end

  "174 #{component["x1"]} #{component["y1"]} #{raw_x2} #{raw_y2} 1 #{max_resistance} #{position} #{slider_label}"
end

def compile_course_component(component)
  case component["type"]
  when "wire"
    "w #{component["x1"]} #{component["y1"]} #{component["x2"]} #{component["y2"]} 0"
  when "battery"
    compile_battery_line(component)
  when "resistor", "internal_resistance"
    compile_resistor_like_line(component)
  when "variable_resistor"
    compile_variable_resistor_line(component)
  when "lamp"
    "181 #{component["x1"]} #{component["y1"]} #{component["x2"]} #{component["y2"]} 0 300 100 120 0.4 0.4"
  when "switch"
    compile_switch_line(component)
  when "ammeter"
    "370 #{component["x1"]} #{component["y1"]} #{component["x2"]} #{component["y2"]} 3 0"
  when "voltmeter"
    "p #{component["x1"]} #{component["y1"]} #{component["x2"]} #{component["y2"]} 3 0 10000000"
  else
    raise "不支援的元件類型：#{component["type"]}"
  end
end

def compile_course_schema_to_falstad(parsed_schema)
  components = Array(parsed_schema["components"] || parsed_schema[:components])
  raise "AI 沒有回傳任何元件。" if components.empty?

  normalized_components = components.each_with_index.map { |component, index| normalize_schema_component(component, index) }
  element_lines = normalized_components.map { |component| compile_course_component(component) }
  label_lines = normalized_components.flat_map { |component| build_component_label_lines(component) }

  ([FALSTAD_HEADER] + element_lines + label_lines).join("\n")
end

def generate_circuit_schema(prompt_text, image_data_url, output_language, api_key, model)
  payloads = [
    build_circuit_schema_payload(prompt_text, image_data_url, output_language, model, compact: false),
    build_circuit_schema_payload(prompt_text, image_data_url, output_language, model, compact: true)
  ]

  status_code, data, model_used = perform_generation(payloads, api_key, model)
  raw_text = extract_output_text(data)
  parsed_schema = parse_circuit_schema_json(raw_text)
  raw_output = append_named_raw_output("", "Circuit Schema", JSON.pretty_generate(parsed_schema))
  [status_code, data, parsed_schema, raw_output, model_used]
rescue GenerationError => e
  raise GenerationError.new(
    e.message,
    raw_output: append_named_raw_output("", "Circuit Schema", e.raw_output),
    status_code: e.status_code,
    upstream_data: e.upstream_data
  )
end

def clean_falstad_code(text)
  cleaned_chunk, _marker = strip_continuation_marker(normalize_model_field(text, preserve_newlines: true))
  cleaned_chunk
end

def generate_circuit_code(prompt_text, image_data_url, output_language, api_key, model)
  emitted_code = ""
  raw_output = ""
  max_chunks = 8

  max_chunks.times do |index|
    payloads = [
      build_circuit_code_payload(prompt_text, image_data_url, output_language, model, emitted_code: emitted_code, compact: false),
      build_circuit_code_payload(prompt_text, image_data_url, output_language, model, emitted_code: emitted_code, compact: true)
    ]

    status_code, data, model_used = perform_generation_relaxed(payloads, api_key, model)
    return [status_code, data, emitted_code, raw_output, model_used] unless status_code.between?(200, 299)

    chunk_text = normalize_model_field(extract_output_text(data), preserve_newlines: true)
    raw_output = append_named_raw_output(raw_output, "Circuit chunk #{index + 1}", build_raw_output(chunk_text, data))
    cleaned_chunk, marker = strip_continuation_marker(chunk_text)
    emitted_code = merge_code_chunks(emitted_code, cleaned_chunk)
    finish_reasons = Array(data["candidates"]).filter_map { |candidate| candidate["finishReason"] }

    return [200, data, clean_falstad_code(emitted_code), raw_output, model_used] if marker == :end
    next if marker == :continue
    next if finish_reasons.include?("MAX_TOKENS") && !cleaned_chunk.empty?
    return [200, data, clean_falstad_code(emitted_code), raw_output, model_used] unless clean_falstad_code(emitted_code).empty?
  end

  raise GenerationError.new(truncation_error_message, raw_output: raw_output)
end

def build_guide_payload(prompt_text, output_language, falstad_code, model)
  instruction_text = [
    output_language.to_s == "en" ? "Your only task is to write a Falstad teaching guide." : "你現在唯一的任務，是輸出 Falstad 視覺化教學指引。",
    output_language.to_s == "en" ? "Write the full response in English." : "整份回應必須使用繁體中文。",
    output_language.to_s == "en" ? "Output plain text only. No JSON, no markdown code fences." : "只輸出純文字，不要 JSON，不要 markdown code fence。",
    output_language.to_s == "en" ? "Do not solve the problem. Do not use formulas. Focus only on what to operate in Falstad and what students should observe." : "不可直接解題，不可使用公式；只聚焦於如何操作 Falstad，以及學生應觀察甚麼。",
    output_language.to_s == "en" ? "Include 4 to 6 short numbered teaching moves." : "請提供 4 至 6 點精簡而具體的教學操作與觀察建議。",
    output_language.to_s == "en" ? "If the circuit is series, remind the teacher to track the single path and the step-like voltage drop. If parallel, remind the teacher to look for branch points and equal top-side voltage." : "若屬串聯，請提醒教師引導學生追蹤單一路徑與階梯式電壓下降；若屬並聯，請提醒教師尋找分岔點與各分支頂部電壓保持一致。"
  ].join("\n")

  request_text = [
    instruction_text,
    "【#{output_language.to_s == "en" ? "User request" : "使用者需求"}】",
    user_request_label(prompt_text, output_language),
    "【Falstad code】",
    falstad_code
  ].join("\n\n")

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => [{ "text" => request_text }]
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: MAX_OUTPUT_TOKENS,
      temperature: 0.2,
      thinking_level: "low"
    )
  }
end

def build_tutor_payload(prompt_text, output_language, falstad_code, model)
  instruction_text = [
    output_language.to_s == "en" ? "Your only task is to write a guided tutoring draft for the teacher." : "你現在唯一的任務，是輸出教師用的引導式解題教學草稿。",
    output_language.to_s == "en" ? "Write the full response in English." : "整份回應必須使用繁體中文。",
    output_language.to_s == "en" ? "Output plain text only. No JSON, no markdown code fences." : "只輸出純文字，不要 JSON，不要 markdown code fence。",
    output_language.to_s == "en" ? "Do not reveal the final answer. Do not use formulas to solve the circuit." : "不可直接給出最終答案，不可用公式代替學生推理。",
    output_language.to_s == "en" ? "Organize the response into four short sections: Lesson goal, Socratic questions, Common misconceptions, and Suggested Falstad interactions." : "請分成四個簡短部分：教學目標、引導式提問、常見迷思、建議的 Falstad 互動操作。",
    output_language.to_s == "en" ? "The questions should help students infer the result by observing current dots, branch points, switch changes, and voltage colors." : "提問要協助學生透過觀察電流小點、分岔點、開關變化與電壓顏色來自行推理。"
  ].join("\n")

  request_text = [
    instruction_text,
    "【#{output_language.to_s == "en" ? "User request" : "使用者需求"}】",
    user_request_label(prompt_text, output_language),
    "【Falstad code】",
    falstad_code
  ].join("\n\n")

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => [{ "text" => request_text }]
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: MAX_OUTPUT_TOKENS,
      temperature: 0.3,
      thinking_level: "medium"
    )
  }
end

def generate_plain_text_task(payload, api_key, model)
  status_code, data, model_used = perform_generation([payload], api_key, model)
  raw_text = normalize_model_field(extract_output_text(data), preserve_newlines: true)
  [status_code, data, raw_text, model_used]
end

JOBS = {}
JOBS_MUTEX = Mutex.new

def cleanup_jobs_locked
  cutoff = Time.now.to_i - JOB_RETENTION_SECONDS
  JOBS.delete_if do |_job_id, job|
    %w[completed failed].include?(job["status"]) && job["updated_at"].to_i < cutoff
  end

  return unless JOBS.length > MAX_STORED_JOBS

  removable_ids = JOBS
    .select { |_job_id, job| %w[completed failed].include?(job["status"]) }
    .sort_by { |_job_id, job| job["updated_at"].to_i }
    .map(&:first)

  removable_ids.first(JOBS.length - MAX_STORED_JOBS).each { |job_id| JOBS.delete(job_id) }
end

def store_job(job_id, payload)
  JOBS_MUTEX.synchronize do
    JOBS[job_id] ||= {}
    JOBS[job_id].merge!(payload)
    JOBS[job_id]["updated_at"] = Time.now.to_i
    cleanup_jobs_locked
  end
end

def fetch_job(job_id)
  JOBS_MUTEX.synchronize do
    job = JOBS[job_id]
    job && job.dup
  end
end

def execute_generate_task(task, prompt_text, image_data_url, output_language, falstad_code_input, api_key, model)
  case task
  when "circuit"
    raise "請提供文字需求或圖片。" if prompt_text.empty? && image_data_url.empty?

    raw_output = ""
    begin
      status_code, upstream_data, parsed_schema, schema_raw_output, model_used = generate_circuit_schema(
        prompt_text,
        image_data_url,
        output_language,
        api_key,
        model
      )
      falstad_code_text = compile_course_schema_to_falstad(parsed_schema)
      raw_output = append_named_raw_output(schema_raw_output, "Compiled Falstad Code", falstad_code_text)
    rescue StandardError => schema_error
      raw_output =
        if schema_error.is_a?(GenerationError)
          schema_error.raw_output.to_s
        else
          append_named_raw_output("", "Circuit Schema", schema_error.message)
        end

      raw_output = append_named_raw_output(raw_output, "Schema Fallback", "Schema compiler failed, so the server retried direct Falstad generation.")

      begin
        status_code, upstream_data, falstad_code_text, direct_raw_output, model_used = generate_circuit_code(
          prompt_text,
          image_data_url,
          output_language,
          api_key,
          model
        )
        raw_output = append_named_raw_output(raw_output, "Direct Falstad Fallback", direct_raw_output)
      rescue GenerationError => direct_error
        raise GenerationError.new(
          direct_error.message,
          raw_output: append_named_raw_output(raw_output, "Direct Falstad Fallback", direct_error.raw_output),
          status_code: direct_error.status_code,
          upstream_data: direct_error.upstream_data
        )
      rescue StandardError => direct_error
        raise GenerationError.new(
          direct_error.message,
          raw_output: append_named_raw_output(raw_output, "Direct Falstad Fallback", direct_error.message)
        )
      end
    end

    unless status_code.between?(200, 299)
      error_message = upstream_data.dig("error", "message") || JSON.generate(upstream_data)
      raise GenerationError.new(error_message, raw_output: raw_output, status_code: status_code, upstream_data: upstream_data)
    end

    falstad_code = normalize_model_field(falstad_code_text, preserve_newlines: true)
    raise "AI 沒有回傳 Falstad 代碼，請再試一次。" if falstad_code.empty?

    {
      "task" => task,
      "falstad_code" => falstad_code,
      "model_used" => model_used,
      "raw_output" => raw_output
    }
  when "guide"
    raise "請先生成或貼上 Falstad 代碼，再進行這一步。" if falstad_code_input.empty?

    status_code, guide_data, guide_text, model_used = generate_plain_text_task(
      build_guide_payload(prompt_text, output_language, falstad_code_input, model),
      api_key,
      model
    )
    raw_output = append_named_raw_output("", "Guide", build_raw_output(guide_text, guide_data))

    unless status_code.between?(200, 299)
      error_message = guide_data.dig("error", "message") || JSON.generate(guide_data)
      raise GenerationError.new(error_message, raw_output: raw_output, status_code: status_code, upstream_data: guide_data)
    end

    raise "AI 沒有回傳教學指引，請再試一次。" if guide_text.empty?

    {
      "task" => task,
      "teaching_guide" => guide_text,
      "model_used" => model_used,
      "raw_output" => raw_output
    }
  when "tutor"
    raise "請先生成或貼上 Falstad 代碼，再進行這一步。" if falstad_code_input.empty?

    status_code, tutor_data, tutor_text, model_used = generate_plain_text_task(
      build_tutor_payload(prompt_text, output_language, falstad_code_input, model),
      api_key,
      model
    )
    raw_output = append_named_raw_output("", "Tutor", build_raw_output(tutor_text, tutor_data))

    unless status_code.between?(200, 299)
      error_message = tutor_data.dig("error", "message") || JSON.generate(tutor_data)
      raise GenerationError.new(error_message, raw_output: raw_output, status_code: status_code, upstream_data: tutor_data)
    end

    raise "AI 沒有回傳解題教學內容，請再試一次。" if tutor_text.empty?

    {
      "task" => task,
      "tutor_response" => tutor_text,
      "model_used" => model_used,
      "raw_output" => raw_output
    }
  else
    raise "不支援的生成任務。"
  end
end

config = load_config

unless ENV["SKIP_SERVER_START"] == "1"
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

  raw_output = ""
  begin
    request_body = JSON.parse(req.body)
    job_id = request_body["jobId"].to_s.strip

    unless job_id.empty?
      job = fetch_job(job_id)

      if job.nil?
        json_response(res, status: 404, body: { error: "找不到這個生成工作，請重新開始。" })
      else
        json_response(res, status: 200, body: job)
      end
      next
    end

    task = request_body["task"].to_s.strip
    task = "circuit" if task.empty?
    prompt_text = request_body["promptText"].to_s.strip
    image_data_url = request_body["imageDataUrl"].to_s.strip
    output_language = request_body["outputLanguage"].to_s.strip
    falstad_code_input = normalize_model_field(request_body["falstadCode"].to_s, preserve_newlines: true)
    job_id = SecureRandom.hex(12)

    store_job(
      job_id,
      {
        "job_id" => job_id,
        "task" => task,
        "status" => "queued",
        "raw_output" => ""
      }
    )

    Thread.new do
      Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
      store_job(job_id, { "status" => "running" })

      begin
        result = execute_generate_task(task, prompt_text, image_data_url, output_language, falstad_code_input, api_key, config["google_model"])
        store_job(job_id, result.merge("job_id" => job_id, "status" => "completed"))
      rescue JSON::ParserError
        store_job(
          job_id,
          {
            "job_id" => job_id,
            "task" => task,
            "status" => "failed",
            "error" => "AI 回應不是有效 JSON，請再按一次 Generate。",
            "raw_output" => ""
          }
        )
      rescue GenerationError => e
        store_job(
          job_id,
          {
            "job_id" => job_id,
            "task" => task,
            "status" => "failed",
            "error" => e.message,
            "raw_output" => e.raw_output.to_s
          }
        )
      rescue StandardError => e
        store_job(
          job_id,
          {
            "job_id" => job_id,
            "task" => task,
            "status" => "failed",
            "error" => e.message,
            "raw_output" => ""
          }
        )
      end
    end

    json_response(
      res,
      status: 202,
      body: {
        "job_id" => job_id,
        "task" => task,
        "status" => "queued"
      }
    )
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
end
