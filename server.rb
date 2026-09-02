require "json"
require "openssl"
require "pathname"
require "securerandom"
require "timeout"
require "uri"
require "webrick"
require "net/http"

ROOT = Pathname.new(__dir__)
CONFIG_PATH = ROOT.join("server-config.local.json")
POE_CHAT_COMPLETIONS_ENDPOINT = URI("https://api.poe.com/v1/chat/completions")
MAX_OUTPUT_TOKENS = 8_192
SCHEMA_MAX_OUTPUT_TOKENS = 8_192
GUIDE_MAX_OUTPUT_TOKENS = 4_096
TUTOR_MAX_OUTPUT_TOKENS = 4_096
API_STATUS_RETRY_ATTEMPTS = 3
ALLOWED_IMAGE_MIME_TYPES = %w[image/png image/jpeg image/webp].freeze
MAX_IMAGE_DATA_BYTES = 8 * 1024 * 1024
POE_OPEN_TIMEOUT = ENV.fetch("POE_OPEN_TIMEOUT", "30").to_i
POE_READ_TIMEOUT = ENV.fetch("POE_READ_TIMEOUT", "240").to_i
POE_TOTAL_TIMEOUT = ENV.fetch("POE_TOTAL_TIMEOUT", "300").to_i
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
FALSTAD_HEADER = "$ 1 0.000005 10.20027730826997 42 5 43"
PHOTO_LAYOUT_ORIGIN_X = 96
PHOTO_LAYOUT_ORIGIN_Y = 64
PHOTO_LAYOUT_WIDTH = 800
PHOTO_LAYOUT_HEIGHT = 640
GRID_SIZE = 16

class GenerationError < StandardError
  attr_reader :raw_output, :status_code, :upstream_data

  def initialize(message, raw_output: "", status_code: nil, upstream_data: nil)
    super(message)
    @raw_output = raw_output.to_s
    @status_code = status_code
    @upstream_data = upstream_data
  end
end

class JobCanceledError < StandardError; end

def load_config
  config = {
    "poe_api_key" => nil,
    "poe_model" => "gemini-3.7-flash",
    "port" => 8080
  }

  if CONFIG_PATH.exist?
    file_config = JSON.parse(CONFIG_PATH.read)
    config.merge!(file_config)
  end

  config["poe_api_key"] = nil if config["poe_api_key"].to_s == "PASTE_YOUR_POE_API_KEY_HERE"
  config["poe_api_key"] = ENV["POE_API_KEY"] if ENV["POE_API_KEY"].to_s.strip != ""
  config["poe_model"] = ENV["POE_MODEL"] if ENV["POE_MODEL"].to_s.strip != ""
  config["port"] = ENV["PORT"].to_i if ENV["PORT"].to_s.strip != ""

  config
end

def usable_api_key?(value)
  key = value.to_s.strip
  !key.empty? && key != "PASTE_YOUR_POE_API_KEY_HERE"
end

def resolve_api_key(request_key, server_key)
  return request_key.to_s.strip if usable_api_key?(request_key)
  return server_key.to_s.strip if usable_api_key?(server_key)

  nil
end

def parse_data_url(data_url)
  match = data_url.match(%r{\Adata:(?<mime>[-\w.+/]+);base64,(?<data>.+)\z})
  return nil unless match

  {
    "mime_type" => match[:mime],
    "data" => match[:data]
  }
end

def user_request_label(prompt_text, output_language)
  return prompt_text unless prompt_text.to_s.empty?

  output_language.to_s == "en" ? "The user uploaded an image without additional text instructions." : "使用者只上載了圖片，沒有提供文字說明。"
end

def thinking_level_for(model, level)
  return nil unless model.to_s.downcase.start_with?("gemini")

  case level.to_s.downcase
  when "low", "medium", "high"
    level.to_s.downcase
  else
    "low"
  end
end

# Poe Chat Completions ignores OpenAI response_format / Gemini responseSchema.
# Keep prompts JSON-only; do not send unused structured-output fields.
def build_generation_config(model, max_tokens:, temperature:, thinking_level: nil)
  config = {
    "temperature" => temperature,
    "maxOutputTokens" => max_tokens
  }

  normalized_thinking_level = thinking_level_for(model, thinking_level)
  config["thinkingLevel"] = normalized_thinking_level if normalized_thinking_level

  config
end

def raise_if_job_canceled!
  job_id = Thread.current[:generation_job_id].to_s
  return if job_id.empty?
  raise JobCanceledError, "生成已停止。" if job_canceled?(job_id)
end

def extract_output_text(data)
  fragments = []
  Array(data["choices"]).each do |choice|
    content = choice.dig("message", "content")
    if content.is_a?(String) && !content.strip.empty?
      fragments << content
    elsif content.is_a?(Array)
      content.each do |part|
        text = part["text"]
        fragments << text if text.is_a?(String) && !text.strip.empty?
      end
    end
  end

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

def upstream_finish_reasons(data)
  Array(data["choices"]).map { |choice| choice["finish_reason"] }.compact +
    Array(data["candidates"]).map { |candidate| candidate["finishReason"] }.compact
end

def response_truncated?(data)
  finish_reasons = upstream_finish_reasons(data)
  return true if finish_reasons.any? { |reason| %w[MAX_TOKENS length].include?(reason.to_s) }

  truncated_json_output?(extract_output_text(data))
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

def normalize_model_field(value, preserve_newlines: false)
  normalized = value.to_s
  normalized = normalized.gsub("\\r\\n", "\n").gsub("\\n", "\n").gsub("\\t", "\t")
  normalized = normalized.gsub("\r\n", "\n")
  normalized = normalized.strip
  preserve_newlines ? normalized : normalized.gsub(/\n{3,}/, "\n\n")
end

def json_response(res, status:, body:)
  res.status = status
  res["Content-Type"] = "application/json; charset=utf-8"
  res.body = JSON.generate(body)
end

def transport_error?(error)
  error.is_a?(EOFError) ||
    error.is_a?(IOError) ||
    error.is_a?(Errno::ENOENT) ||
    error.is_a?(Errno::ECONNRESET) ||
    error.is_a?(Net::ReadTimeout) ||
    error.is_a?(OpenSSL::SSL::SSLError) ||
    error.is_a?(Timeout::Error)
end

def retryable_upstream_status?(status_code, data)
  return false unless [408, 429, 500, 502, 503, 504, 529].include?(status_code.to_i)

  upstream_status = data.dig("error", "status").to_s
  upstream_type = data.dig("error", "type").to_s
  upstream_status.empty? ||
    %w[UNAVAILABLE RESOURCE_EXHAUSTED INTERNAL DEADLINE_EXCEEDED].include?(upstream_status) ||
    %w[timeout_error rate_limit_error provider_error upstream_error overloaded_error].include?(upstream_type)
end

def transport_error_message?(error)
  transport_error?(error) ||
    error.message.to_s.include?("end of file reached") ||
    error.message.to_s.include?("execution expired")
end

def poe_content_from_parts(parts)
  content_parts = []

  Array(parts).each do |part|
    text = part["text"]
    content_parts << { "type" => "text", "text" => text } if text.is_a?(String) && !text.strip.empty?

    inline_data = part["inline_data"]
    next unless inline_data.is_a?(Hash)

    mime_type = inline_data["mime_type"].to_s
    data = inline_data["data"].to_s
    next if mime_type.empty? || data.empty?

    content_parts << {
      "type" => "image_url",
      "image_url" => {
        "url" => "data:#{mime_type};base64,#{data}"
      }
    }
  end

  return "" if content_parts.empty?
  return content_parts.first["text"] if content_parts.length == 1 && content_parts.first["type"] == "text"

  content_parts
end

def poe_payload_from_generation_payload(payload, model)
  generation_config = payload["generationConfig"] || {}
  messages = Array(payload["contents"]).map do |content|
    role = content["role"].to_s == "model" ? "assistant" : "user"
    {
      "role" => role,
      "content" => poe_content_from_parts(content["parts"])
    }
  end

  request_payload = {
    "model" => model,
    "messages" => messages,
    "temperature" => generation_config["temperature"],
    "max_tokens" => generation_config["maxOutputTokens"]
  }

  thinking_level = generation_config["thinkingLevel"]
  request_payload["extra_body"] = { "thinking_level" => thinking_level } if thinking_level

  request_payload.delete_if { |_key, value| value.nil? || value == "" }
end

def request_poe_via_net_http(payload, api_key, model)
  Timeout.timeout(POE_TOTAL_TIMEOUT) do
    endpoint = POE_CHAT_COMPLETIONS_ENDPOINT
    http = Net::HTTP.new(endpoint.host, endpoint.port)
    http.use_ssl = true
    http.open_timeout = POE_OPEN_TIMEOUT
    http.read_timeout = POE_READ_TIMEOUT
    http.keep_alive_timeout = 0

    upstream_req = Net::HTTP::Post.new(endpoint)
    upstream_req["Authorization"] = "Bearer #{api_key}"
    upstream_req["Content-Type"] = "application/json"
    upstream_req["Connection"] = "close"
    upstream_req.body = JSON.generate(poe_payload_from_generation_payload(payload, model))

    upstream_res = http.request(upstream_req)
    [upstream_res.code.to_i, upstream_res.body]
  end
end

def request_poe(payload, api_key, model)
  raise_if_job_canceled!
  request_poe_via_net_http(payload, api_key, model)
end

def perform_generation(payloads, api_key, preferred_model, reject_truncated: true)
  last_error = nil

  payloads.each do |payload|
    API_STATUS_RETRY_ATTEMPTS.times do |attempt|
      begin
        raise_if_job_canceled!
        status_code, body = request_poe(payload, api_key, preferred_model)
        parsed = JSON.parse(body)

        if reject_truncated && status_code.between?(200, 299) && response_truncated?(parsed)
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
      rescue JobCanceledError
        raise
      rescue StandardError => e
        last_error = e
        sleep(attempt + 1) if attempt < API_STATUS_RETRY_ATTEMPTS - 1
      end
    end
  end

  raise last_error if last_error
  raise "Poe API 請求失敗。"
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
    unless ALLOWED_IMAGE_MIME_TYPES.include?(inline_data["mime_type"].to_s.downcase)
      raise "只接受 PNG、JPEG 或 WebP 圖片。"
    end
    if inline_data["data"].to_s.bytesize > MAX_IMAGE_DATA_BYTES
      raise "圖片太大，請改用較小的檔案或先裁切後再上載。"
    end

    parts << { "inline_data" => inline_data }
  end

  parts
end

def build_circuit_schema_payload(prompt_text, image_data_url, output_language, model, compact: false)
  instruction_lines =
    if output_language.to_s == "en"
      [
        "Output one JSON object for a Hong Kong secondary-school circuit schema.",
        "Return JSON text only. Do not include markdown fences, prose, comments, or trailing explanation.",
        "The top-level object must include a components array. If the request is simple, still output every needed component and wire.",
        "For real photos, use photo-layout coordinates: normalized decimals from 0 to 1 relative to the photo, preserving photographed positions. The server will snap them onto the Falstad 16-grid when compiling Falstad code.",
        "For each real photographed component, provide bbox [left, top, right, bottom], orientation, and either x1/y1/x2/y2 terminal coordinates or terminals {a:[x,y], b:[x,y]}.",
        "Use x1/y1/x2/y2 for the two electrical terminals. Photos may use 0-to-1 values; text-only requests may already use Falstad 16-grid integers. Do not require schema coordinates themselves to be multiples of 16.",
        "For battery, Falstad polarity is required: x1/y1 is the negative terminal (short plate), x2/y2 is the positive terminal (long plate). In textbook diagrams the long line is positive. Do not use left-to-right or top-to-bottom order instead of polarity. If you also give terminals, use {negative:[x,y], positive:[x,y]}. Do not rely on bbox alone for a battery.",
        "The JSON must use only these component types: wire, battery, resistor, internal_resistance, variable_resistor, lamp, switch, ammeter, voltmeter.",
        "Use components only. Do not output raw Falstad dump lines.",
        "The compiled Falstad code must use integer coordinates that are multiples of 16. The server performs that snap for every input, text or photo.",
        "Every wire, resistor, lamp, switch, ammeter, voltmeter, battery, and internal_resistance must be horizontal or vertical.",
        "Use wire components to build corners, rectangles, and branches.",
        "For real laboratory photos, first convert the physical setup into a clean schematic: trace only connected terminals and leads; ignore tables, hands, shadows, unused loose wires, and background objects.",
        "Map common school apparatus to the schema: cell holders or power packs become battery, bulb holders become lamp, crocodile-clip leads become wire, rheostats become variable_resistor, A/V meters become ammeter or voltmeter, and switch keys become switch.",
        "If a photographed wire is curved or messy, do not copy its shape; preserve only the topology by connecting the same terminal nodes with straight horizontal or vertical wires.",
        "If part of a photo is ambiguous, choose the simplest Hong Kong secondary-school component that fits, mention the uncertainty briefly in summary, and still output a valid schema.",
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
        "只輸出 JSON 文字。不要 markdown code fence，不要解釋，不要註解，不要在 JSON 後加任何文字。",
        "最外層 object 必須包含 components array。即使需求很簡單，也要輸出所有需要的元件和導線。",
        "如果是真實相片，請使用 photo-layout coordinates：用 0 至 1 的小數表示相對於相片的位置，保留相片中的相對擺位。server 編譯 Falstad code 時會自動 snap 到 16 格。",
        "每個相片中的實物 component 請提供 bbox [left, top, right, bottom]、orientation，以及 x1/y1/x2/y2 端子座標或 terminals {a:[x,y], b:[x,y]}。",
        "x1/y1/x2/y2 代表兩個電氣端子。相片可用 0 至 1 normalized 座標；純文字需求可直接用 Falstad 16 格整數。schema 本身不必是 16 的倍數。",
        "battery 必須遵守 Falstad 極向：x1/y1 是負極（短極板），x2/y2 是正極（長極板）。課本圖中長線是正極。不要用由左到右或由上到下代替極向。若同時提供 terminals，請用 {negative:[x,y], positive:[x,y]}。電池不要只靠 bbox。",
        "JSON 只可使用這些元件類型：wire、battery、resistor、internal_resistance、variable_resistor、lamp、switch、ammeter、voltmeter。",
        "請只輸出 schema，不要輸出原始 Falstad dump 代碼。",
        "最終 Falstad code 的每個座標都必須是整數，而且一定要是 16 的倍數。無論文字或相片輸入，都由 server 負責 snap。",
        "wire、resistor、lamp、switch、ammeter、voltmeter、battery、internal_resistance 都必須保持水平或垂直。",
        "所有轉角、長方形框架、分支都請用 wire 元件補齊。",
        "如果輸入是真實實驗室相片，請先把實物連接轉成乾淨的電路圖：只追蹤真正連接的端子與導線，忽略桌面、手、陰影、未接上的鬆散導線和背景物件。",
        "請把常見學校儀器對應到 schema：電池盒或電源供應器是 battery，燈座/燈泡是 lamp，鱷魚夾導線是 wire，滑動變阻器/變阻器是 variable_resistor，A/V 錶是 ammeter 或 voltmeter，開關掣是 switch。",
        "如果相片中的導線彎曲或凌亂，不要複製實物形狀；只保留拓撲，用水平或垂直直線連接相同端點。",
        "如果相片部分位置不清楚，請選擇最符合香港中學程度的簡單元件，在 summary 簡短說明不確定之處，但仍要輸出有效 schema。",
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
      max_tokens: SCHEMA_MAX_OUTPUT_TOKENS,
      temperature: 0,
      thinking_level: "low"
    )
  }
end

def build_circuit_schema_retry_payload(prompt_text, image_data_url, output_language, model, failed_output, error_message)
  instruction_text =
    if output_language.to_s == "en"
      [
        "Regenerate the Hong Kong secondary-school circuit schema as valid JSON.",
        "The previous schema failed validation: #{error_message}",
        "Output JSON only. No markdown fences, no prose, no comments.",
        "The top-level object must contain components.",
        "For photos, preserve photographed positions using normalized 0-to-1 coordinates. Prefer bbox [left, top, right, bottom], orientation, and terminal coordinates x1/y1/x2/y2 or terminals {a:[x,y], b:[x,y]}.",
        "x1/y1/x2/y2 are the two electrical terminals. Use normalized photo coordinates or 16-grid Falstad coordinates.",
        "For battery, x1/y1 must be the negative/short plate and x2/y2 the positive/long plate. Prefer terminals {negative:[x,y], positive:[x,y]}.",
        "Use only these types: wire, battery, resistor, internal_resistance, variable_resistor, lamp, switch, ammeter, voltmeter.",
        "All compiled components must be horizontal or vertical. The server will snap schema coordinates to Falstad multiples of 16 for both text and photo inputs.",
        "For the photo, trace only connected terminals and leads; ignore loose unused leads and background objects.",
        "Do not output Falstad dump code."
      ].join("\n")
    else
      [
        "請重新生成香港中學物理電路 schema，並輸出有效 JSON。",
        "上一個 schema 驗證失敗：#{error_message}",
        "只輸出 JSON。不要 markdown code fence，不要解釋，不要註解。",
        "最外層 object 必須包含 components。",
        "如果是相片，請用 0 至 1 normalized 座標保留相片擺位。優先提供 bbox [left, top, right, bottom]、orientation，以及 x1/y1/x2/y2 或 terminals {a:[x,y], b:[x,y]} 端子座標。",
        "x1/y1/x2/y2 代表兩個電氣端子。可用 normalized 相片座標或 16 倍數 Falstad 座標。",
        "battery 的 x1/y1 必須是負極（短極板），x2/y2 必須是正極（長極板）。優先使用 terminals {negative:[x,y], positive:[x,y]}。",
        "只可使用這些 type：wire、battery、resistor、internal_resistance、variable_resistor、lamp、switch、ammeter、voltmeter。",
        "編譯後的元件必須水平或垂直；無論文字或相片，server 都會把 schema 座標 snap 成 Falstad 16 倍數整數。",
        "如果是相片，只追蹤真正連接的端子與導線，忽略未接上的鬆散導線和背景物件。",
        "不要輸出 Falstad dump code。"
      ].join("\n")
    end

  failed_text = failed_output.to_s.strip
  failed_text = failed_text[0, 3000] + "\n...[truncated]" if failed_text.length > 3000
  retry_text = [instruction_text, "【Invalid previous output】", failed_text].join("\n\n")

  {
    "contents" => [
      {
        "role" => "user",
        "parts" => build_task_parts(prompt_text, image_data_url, retry_text, output_language)
      }
    ],
    "generationConfig" => build_generation_config(
      model,
      max_tokens: SCHEMA_MAX_OUTPUT_TOKENS,
      temperature: 0,
      thinking_level: "low"
    )
  }
end

def build_circuit_code_payload(prompt_text, image_data_url, output_language, model, emitted_code: "", compact: false)
  instruction_lines = [
    output_language.to_s == "en" ? "Your only task is to output Falstad circuit code that can be imported directly." : "你現在唯一的任務，是輸出可直接匯入 Falstad 的電路代碼。",
    output_language.to_s == "en" ? "Output only plain Falstad code. No JSON, no markdown, no explanations." : "只輸出 Falstad 純文字代碼，不要 JSON，不要 markdown，不要解釋。",
    output_language.to_s == "en" ? "Every X and Y coordinate in the Falstad code must be an integer multiple of 16, whether the user provided text or a photo." : "無論使用者輸入文字或相片，Falstad code 裡每一個 X 與 Y 座標都必須是 16 的倍數整數。",
    output_language.to_s == "en" ? "Use legal Falstad elements only. Use 6V or 9V batteries when needed." : "只使用合法的 Falstad 元件；如需要電池，請用 6V 或 9V。",
    output_language.to_s == "en" ? "Never use shorthand element lines. Use these exact formats: battery `v x1 y1 x2 y2 0 0 40 voltage 0 0 0.5`; switch `s x1 y1 x2 y2 0 position false`; resistor `r x1 y1 x2 y2 0 resistance`; wire `w x1 y1 x2 y2 0`." : "絕不可使用簡寫元件行。請使用這些完整格式：電池 `v x1 y1 x2 y2 0 0 40 voltage 0 0 0.5`；開關 `s x1 y1 x2 y2 0 position false`；電阻 `r x1 y1 x2 y2 0 resistance`；導線 `w x1 y1 x2 y2 0`。",
    output_language.to_s == "en" ? "For a battery, (x1,y1) is the negative short plate and (x2,y2) is the positive long plate. For example, a 9V battery must be `v 160 240 160 160 0 0 40 9 0 0 0.5`, not `v 160 240 160 160 0 9`." : "電池的 (x1,y1) 是負極短極板，(x2,y2) 是正極長極板。例如 9V 電池必須寫成 `v 160 240 160 160 0 0 40 9 0 0 0.5`，不可寫成 `v 160 240 160 160 0 9`。",
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
  raise "AI 沒有回傳任何元件。" if Array(parsed["components"] || parsed[:components]).empty?

  parsed
end

def snap_to_grid(value)
  ((value.to_f / GRID_SIZE).round * GRID_SIZE).to_i
end

def schema_coordinate!(value, key)
  number = Float(value)
  if number >= 0.0 && number <= 1.0
    axis = key.to_s.include?("x") ? :x : :y
    base = axis == :x ? PHOTO_LAYOUT_ORIGIN_X : PHOTO_LAYOUT_ORIGIN_Y
    span = axis == :x ? PHOTO_LAYOUT_WIDTH : PHOTO_LAYOUT_HEIGHT
    return snap_to_grid(base + (number * span))
  end

  snap_to_grid(number)
rescue ArgumentError, TypeError
  raise "#{key} 必須是數值座標。"
end

def positive_number(value, default)
  number = value.nil? ? default : value.to_f
  number.positive? ? number : default
end

def bounded_ratio(value, default = 0.5)
  number = value.nil? ? default : value.to_f
  [[number, 0.05].max, 0.95].min
end

def coordinate_pair(value)
  if value.is_a?(Array) && value.length >= 2
    return [value[0], value[1]]
  end

  if value.is_a?(Hash)
    keyed = value.transform_keys(&:to_s)
    x = keyed["x"] || keyed["0"]
    y = keyed["y"] || keyed["1"]
    return [x, y] unless x.nil? || y.nil?
  end

  nil
end

BATTERY_NEGATIVE_KEYS = %w[negative minus black neg -].freeze
BATTERY_POSITIVE_KEYS = %w[positive plus red pos +].freeze

def lookup_named_coordinate(source, keys)
  return nil unless source.is_a?(Hash)

  keyed = source.transform_keys { |key| key.to_s.downcase }
  keys.each do |key|
    pair = coordinate_pair(keyed[key])
    return pair if pair
  end
  nil
end

def polarity_terminal_pair(component)
  negative = lookup_named_coordinate(component, BATTERY_NEGATIVE_KEYS)
  positive = lookup_named_coordinate(component, BATTERY_POSITIVE_KEYS)
  if component["terminals"].is_a?(Hash)
    negative ||= lookup_named_coordinate(component["terminals"], BATTERY_NEGATIVE_KEYS)
    positive ||= lookup_named_coordinate(component["terminals"], BATTERY_POSITIVE_KEYS)
  end
  return [negative, positive] if negative && positive

  nil
end

def apply_battery_polarity!(component)
  pair = polarity_terminal_pair(component)
  return component unless pair

  negative, positive = pair
  component["x1"] = negative[0]
  component["y1"] = negative[1]
  component["x2"] = positive[0]
  component["y2"] = positive[1]
  component
end

def terminal_pair_from_component(component)
  terminals = component["terminals"]
  return nil unless terminals.is_a?(Hash)

  keyed = terminals.transform_keys { |key| key.to_s.downcase }
  key_pairs = [
    %w[a b],
    %w[t1 t2],
    %w[terminal1 terminal2],
    %w[left right],
    %w[top bottom]
  ]

  key_pairs.each do |first_key, second_key|
    first_pair = coordinate_pair(keyed[first_key])
    second_pair = coordinate_pair(keyed[second_key])
    return [first_pair, second_pair] if first_pair && second_pair
  end

  pairs = keyed.values.map { |value| coordinate_pair(value) }.compact
  pairs.length >= 2 ? pairs.first(2) : nil
end

def endpoint_pair_from_bbox(component)
  bbox = component["bbox"]
  return nil unless bbox.is_a?(Array) && bbox.length >= 4

  left, top, right, bottom = bbox.first(4).map(&:to_f)
  left, right = [left, right].minmax
  top, bottom = [top, bottom].minmax
  center_x = (left + right) / 2.0
  center_y = (top + bottom) / 2.0
  width = right - left
  height = bottom - top

  orientation = component["orientation"].to_s.downcase
  orientation = width >= height ? "horizontal" : "vertical" unless %w[horizontal vertical].include?(orientation)

  if orientation == "vertical"
    [[center_x, top], [center_x, bottom]]
  else
    [[left, center_y], [right, center_y]]
  end
end

def apply_schema_endpoint_aliases!(component)
  endpoint_pairs = [
    ["p1", "p2"],
    ["from", "to"],
    ["start", "end"],
    ["terminal1", "terminal2"],
    ["t1", "t2"],
    ["a", "b"],
    ["left", "right"],
    ["top", "bottom"]
  ]

  endpoint_pairs.each do |first_key, second_key|
    first_pair = coordinate_pair(component[first_key])
    second_pair = coordinate_pair(component[second_key])
    next unless first_pair && second_pair

    component["x1"] ||= first_pair[0]
    component["y1"] ||= first_pair[1]
    component["x2"] ||= second_pair[0]
    component["y2"] ||= second_pair[1]
    break
  end

  terminal_pair = terminal_pair_from_component(component)
  if terminal_pair
    component["x1"] ||= terminal_pair[0][0]
    component["y1"] ||= terminal_pair[0][1]
    component["x2"] ||= terminal_pair[1][0]
    component["y2"] ||= terminal_pair[1][1]
  end

  bbox_pair = endpoint_pair_from_bbox(component)
  if bbox_pair
    component["x1"] ||= bbox_pair[0][0]
    component["y1"] ||= bbox_pair[0][1]
    component["x2"] ||= bbox_pair[1][0]
    component["y2"] ||= bbox_pair[1][1]
  end

  component
end

def orthogonalize_component!(component)
  return component if component["type"] == "variable_resistor"
  return component if component["x1"] == component["x2"] || component["y1"] == component["y2"]

  orientation = component["orientation"].to_s.downcase
  unless %w[horizontal vertical].include?(orientation)
    orientation = (component["x2"] - component["x1"]).abs >= (component["y2"] - component["y1"]).abs ? "horizontal" : "vertical"
  end

  if orientation == "vertical"
    component["x2"] = component["x1"]
  else
    component["y2"] = component["y1"]
  end

  component
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
  apply_schema_endpoint_aliases!(normalized)
  normalized["type"] = normalize_component_type(normalized["type"])
  raise "第 #{index + 1} 個元件缺少有效 type。" unless SUPPORTED_CIRCUIT_COMPONENT_TYPES.include?(normalized["type"])
  apply_battery_polarity!(normalized) if normalized["type"] == "battery"

  %w[x1 y1 x2 y2].each do |key|
    normalized[key] = schema_coordinate!(normalized[key], "元件 #{index + 1} 的 #{key}")
  end

  orthogonalize_component!(normalized)

  if normalized["type"] != "variable_resistor" && normalized["x1"] != normalized["x2"] && normalized["y1"] != normalized["y2"]
    raise "元件 #{index + 1}（#{normalized["type"]}）必須保持水平或垂直。"
  end

  if normalized["type"] == "variable_resistor"
    unless normalized["x1"] == normalized["x2"] || normalized["y1"] == normalized["y2"]
      raise "variable_resistor 的主體必須保持水平或垂直。"
    end

    if normalized["y1"] == normalized["y2"]
      normalized["wiper_x"] = schema_coordinate!(normalized["wiper_x"] || ((normalized["x1"] + normalized["x2"]) / 2), "元件 #{index + 1} 的 wiper_x")
      normalized["wiper_y"] = schema_coordinate!(normalized["wiper_y"], "元件 #{index + 1} 的 wiper_y")
    else
      normalized["wiper_x"] = schema_coordinate!(normalized["wiper_x"], "元件 #{index + 1} 的 wiper_x")
      normalized["wiper_y"] = schema_coordinate!(normalized["wiper_y"] || ((normalized["y1"] + normalized["y2"]) / 2), "元件 #{index + 1} 的 wiper_y")
    end
  end

  normalized
end

def compile_battery_line(component)
  voltage = positive_number(component["voltage"], 9)
  # Falstad DC battery: (x1,y1) = negative short plate, (x2,y2) = positive long plate.
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
  raise_if_job_canceled!
  first_payload = build_circuit_schema_payload(prompt_text, image_data_url, output_language, model, compact: false)
  status_code, data, model_used = perform_generation([first_payload], api_key, model)
  raw_text = extract_output_text(data)
  raw_output = ""

  begin
    parsed_schema = parse_circuit_schema_json(raw_text)
  rescue StandardError => first_error
    raise if first_error.is_a?(JobCanceledError)

    raw_output = append_named_raw_output(raw_output, "Circuit Schema", build_raw_output(raw_text, data))
    raise_if_job_canceled!
    retry_payload = build_circuit_schema_retry_payload(prompt_text, image_data_url, output_language, model, raw_text, first_error.message)
    status_code, data, model_used = perform_generation([retry_payload], api_key, model)
    raw_text = extract_output_text(data)
    parsed_schema = parse_circuit_schema_json(raw_text)
    raw_output = append_named_raw_output(raw_output, "Circuit Schema Retry", JSON.pretty_generate(parsed_schema))
  else
    raw_output = append_named_raw_output(raw_output, "Circuit Schema", JSON.pretty_generate(parsed_schema))
  end

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
  normalize_falstad_dump_lines(cleaned_chunk)
end

def finalize_falstad_code(emitted_code, raw_output)
  raw_code, _marker = strip_continuation_marker(normalize_model_field(emitted_code, preserve_newlines: true))
  final_code = normalize_falstad_dump_lines(raw_code)

  if !final_code.empty? && final_code != raw_code
    raw_output = append_named_raw_output(raw_output, "Normalized Falstad Code", final_code)
  end

  [final_code, raw_output]
end

def snap_falstad_line_coordinates(line)
  parts = line.to_s.split(/\s+/)
  return line if parts.empty? || parts.first == "$"

  (1..4).each do |index|
    value = parts[index]
    next unless value.to_s.match?(/\A-?\d+(?:\.\d+)?\z/)

    parts[index] = snap_to_grid(value).to_s
  end

  parts.join(" ")
end

def normalize_falstad_dump_lines(code)
  code.to_s.split("\n").map do |line|
    stripped = snap_falstad_line_coordinates(line.strip)
    parts = stripped.split(/\s+/)

    case parts.first
    when "v"
      if parts.length == 7
        voltage = positive_number(parts[6], 9)
        "v #{parts[1]} #{parts[2]} #{parts[3]} #{parts[4]} 0 0 40 #{voltage} 0 0 0.5"
      else
        stripped
      end
    when "s"
      if parts.length == 7
        "#{stripped} false"
      else
        stripped
      end
    else
      stripped
    end
  end.join("\n").strip
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

    raise_if_job_canceled!
    status_code, data, model_used = perform_generation(payloads, api_key, model, reject_truncated: false)
    return [status_code, data, emitted_code, raw_output, model_used] unless status_code.between?(200, 299)

    chunk_text = normalize_model_field(extract_output_text(data), preserve_newlines: true)
    raw_output = append_named_raw_output(raw_output, "Circuit chunk #{index + 1}", build_raw_output(chunk_text, data))
    cleaned_chunk, marker = strip_continuation_marker(chunk_text)
    emitted_code = merge_code_chunks(emitted_code, cleaned_chunk)
    finish_reasons = upstream_finish_reasons(data)

    if marker == :end
      final_code, raw_output = finalize_falstad_code(emitted_code, raw_output)
      return [200, data, final_code, raw_output, model_used]
    end

    next if marker == :continue
    next if finish_reasons.any? { |reason| %w[MAX_TOKENS length].include?(reason.to_s) } && !cleaned_chunk.empty?

    final_code, raw_output = finalize_falstad_code(emitted_code, raw_output)
    return [200, data, final_code, raw_output, model_used] unless final_code.empty?
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
      max_tokens: GUIDE_MAX_OUTPUT_TOKENS,
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
      max_tokens: TUTOR_MAX_OUTPUT_TOKENS,
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
JOB_THREADS = {}
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
    current = JOBS[job_id]
    if current && current["status"] == "canceled" && payload["status"] != "canceled"
      return current.dup
    end

    JOBS[job_id] ||= {}
    JOBS[job_id].merge!(payload)
    JOBS[job_id]["updated_at"] = Time.now.to_i
    cleanup_jobs_locked
  end
end

def register_job_thread(job_id, thread)
  JOBS_MUTEX.synchronize do
    return if %w[completed failed canceled].include?(JOBS.dig(job_id, "status"))
    return unless thread&.alive?

    JOB_THREADS[job_id] = thread
  end
end

def unregister_job_thread(job_id)
  JOBS_MUTEX.synchronize do
    JOB_THREADS.delete(job_id)
  end
end

def fetch_job(job_id)
  JOBS_MUTEX.synchronize do
    job = JOBS[job_id]
    job && job.dup
  end
end

def job_canceled?(job_id)
  JOBS_MUTEX.synchronize do
    JOBS.dig(job_id, "status") == "canceled"
  end
end

def cancel_job(job_id)
  JOBS_MUTEX.synchronize do
    job = JOBS[job_id]
    return nil unless job

    unless %w[completed failed canceled].include?(job["status"])
      job["status"] = "canceled"
      job["error"] = "生成已停止。"
      job["updated_at"] = Time.now.to_i
    end

    JOB_THREADS.delete(job_id)
    job.dup
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
      raise if schema_error.is_a?(JobCanceledError)

      raw_output =
        if schema_error.is_a?(GenerationError)
          schema_error.raw_output.to_s
        else
          append_named_raw_output("", "Circuit Schema", schema_error.message)
        end

      unless image_data_url.empty?
        if transport_error_message?(schema_error)
          raise GenerationError.new(
            "Poe API 連線逾時或中斷，請再試一次。",
            raw_output: raw_output,
            status_code: schema_error.respond_to?(:status_code) ? schema_error.status_code : nil,
            upstream_data: schema_error.respond_to?(:upstream_data) ? schema_error.upstream_data : nil
          )
        end

        raise GenerationError.new(
          "相片未能生成有效 schema，請再試一次，或在文字提示補充各端子連接方式。",
          raw_output: raw_output,
          status_code: schema_error.respond_to?(:status_code) ? schema_error.status_code : nil,
          upstream_data: schema_error.respond_to?(:upstream_data) ? schema_error.upstream_data : nil
        )
      end

      raw_output = append_named_raw_output(raw_output, "Schema Fallback", "Schema compiler failed, so the server retried direct Falstad generation.")
      raise_if_job_canceled!

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

    falstad_code, raw_output = finalize_falstad_code(falstad_code_text, raw_output)
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

server.mount_proc "/examples.md" do |_req, res|
  path = ROOT.join("examples.md")
  unless path.exist?
    res.status = 404
    res["Content-Type"] = "text/plain; charset=utf-8"
    res.body = "examples.md not found"
    next
  end

  res.status = 200
  res["Content-Type"] = "text/markdown; charset=utf-8"
  res["Cache-Control"] = "no-store"
  res.body = path.read
end

server.mount_proc "/manual.md" do |_req, res|
  path = ROOT.join("說明書.md")
  unless path.exist?
    res.status = 404
    res["Content-Type"] = "text/plain; charset=utf-8"
    res.body = "說明書.md not found"
    next
  end

  res.status = 200
  res["Content-Type"] = "text/plain; charset=utf-8"
  res["Cache-Control"] = "no-store"
  res.body = path.read
end

server.mount_proc "/api/health" do |_req, res|
  json_response(
    res,
    status: 200,
    body: {
      ok: true,
      provider: "poe-api",
      has_api_key: usable_api_key?(config["poe_api_key"]),
      model: config["poe_model"]
    }
  )
end

server.mount_proc "/api/generate" do |req, res|
  unless req.request_method == "POST"
    json_response(res, status: 405, body: { error: "Method not allowed" })
    next
  end

  raw_output = ""
  begin
    request_body = JSON.parse(req.body)
    cancel_job_id = request_body["cancelJobId"].to_s.strip

    unless cancel_job_id.empty?
      job = cancel_job(cancel_job_id)

      if job.nil?
        json_response(res, status: 404, body: { error: "找不到這個生成工作，請重新開始。" })
      else
        json_response(res, status: 200, body: job)
      end
      next
    end

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

    api_key = resolve_api_key(request_body["apiKey"], config["poe_api_key"])
    unless api_key
      json_response(res, status: 400, body: { error: "請先在網頁右上角填入 Poe API key。" })
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

    worker = Thread.new do
      Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
      Thread.current[:generation_job_id] = job_id
      next if job_canceled?(job_id)

      store_job(job_id, { "status" => "running" })

      begin
        next if job_canceled?(job_id)

        result = execute_generate_task(task, prompt_text, image_data_url, output_language, falstad_code_input, api_key, config["poe_model"])
        next if job_canceled?(job_id)

        store_job(job_id, result.merge("job_id" => job_id, "status" => "completed"))
      rescue JobCanceledError
        next
      rescue JSON::ParserError
        next if job_canceled?(job_id)

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
        next if job_canceled?(job_id)

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
        next if job_canceled?(job_id)

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
      ensure
        unregister_job_thread(job_id)
      end
    end

    register_job_thread(job_id, worker)

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
