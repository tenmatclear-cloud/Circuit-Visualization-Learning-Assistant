# Frozen constants below come from server.rb when this file is required there.
# Tests may load this file after defining GRID_SIZE, PHOTO_LAYOUT_*, FALSTAD_HEADER,
# and SUPPORTED_CIRCUIT_COMPONENT_TYPES.

NODE_MERGE_RADIUS = GRID_SIZE / 2.0
FLOATING_REATTACH_MAX_DISTANCE = GRID_SIZE * 3
FLOATING_REATTACH_MIN_T = 0.15
FLOATING_REATTACH_MAX_T = 0.85
DIAGONAL_ORIENTATION_PATTERN = /diag|oblique|slant|tilt|bridge/.freeze
SWITCH_OPEN_STATES = %w[open off opened 開 打開 斷 斷開].freeze
SWITCH_CLOSED_STATES = %w[closed on close 關 閉合 合上 接通].freeze
REATTACHABLE_TYPES = %w[resistor lamp internal_resistance].freeze
UNORDERED_TWO_TERMINAL_TYPES = %w[wire resistor lamp internal_resistance].freeze
BATTERY_NEGATIVE_KEYS = %w[negative minus black neg -].freeze
BATTERY_POSITIVE_KEYS = %w[positive plus red pos +].freeze
# Falstad draws resistor/switch bodies at a fixed ~32 circuit pixels, then zooms
# to fit. Photo-layout canvases (~800px) make that zoom tiny next to hand examples.
TARGET_LAYOUT_MAX = 400

def snap_to_grid(value)
  ((value.to_f / GRID_SIZE).round * GRID_SIZE).to_i
end

def map_schema_coordinate(value, key)
  number = Float(value)
  if number >= 0.0 && number <= 1.0
    axis = key.to_s.include?("x") ? :x : :y
    base = axis == :x ? PHOTO_LAYOUT_ORIGIN_X : PHOTO_LAYOUT_ORIGIN_Y
    span = axis == :x ? PHOTO_LAYOUT_WIDTH : PHOTO_LAYOUT_HEIGHT
    return base + (number * span)
  end

  number
rescue ArgumentError, TypeError
  raise "#{key} 必須是數值座標。"
end

def schema_coordinate!(value, key)
  snap_to_grid(map_schema_coordinate(value, key))
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

def diagonal_orientation?(component)
  DIAGONAL_ORIENTATION_PATTERN.match?(component["orientation"].to_s)
end

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
    %w[from to],
    %w[start end],
    %w[left right],
    %w[top bottom],
    %w[n1 n2],
    %w[node1 node2]
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
  return nil if diagonal_orientation?(component)

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
    ["top", "bottom"],
    ["node_a", "node_b"],
    ["n1", "n2"]
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

def component_point(component, x_key, y_key)
  [component[x_key], component[y_key]]
end

def component_end_points(component)
  points = [component_point(component, "x1", "y1"), component_point(component, "x2", "y2")]
  if component["type"] == "variable_resistor"
    points << component_point(component, "wiper_x", "wiper_y")
  end
  points
end

def component_length(component)
  Math.hypot(component["x2"] - component["x1"], component["y2"] - component["y1"])
end

def zero_length?(component)
  component["x1"] == component["x2"] && component["y1"] == component["y2"]
end

def unordered_ends(component)
  [component_point(component, "x1", "y1"), component_point(component, "x2", "y2")].sort
end

def projection_t(px, py, x1, y1, x2, y2)
  dx = x2 - x1
  dy = y2 - y1
  length_sq = (dx * dx) + (dy * dy)
  return 0.0 if length_sq.zero?

  (((px - x1) * dx) + ((py - y1) * dy)) / length_sq.to_f
end

def point_to_segment_distance(px, py, x1, y1, x2, y2)
  t = projection_t(px, py, x1, y1, x2, y2)
  t = [[t, 0.0].max, 1.0].min
  qx = x1 + (t * (x2 - x1))
  qy = y1 + (t * (y2 - y1))
  Math.hypot(px - qx, py - qy)
end

def point_on_segment?(px, py, x1, y1, x2, y2, tol = 0.5)
  t = projection_t(px, py, x1, y1, x2, y2)
  return false if t <= 0.0 || t >= 1.0

  point_to_segment_distance(px, py, x1, y1, x2, y2) <= tol
end

def parse_schema_component(component, index)
  raise "第 #{index + 1} 個元件不是有效物件。" unless component.is_a?(Hash)

  normalized = component.transform_keys(&:to_s)
  apply_schema_endpoint_aliases!(normalized)
  normalized["type"] = normalize_component_type(normalized["type"])
  raise "第 #{index + 1} 個元件缺少有效 type。" unless SUPPORTED_CIRCUIT_COMPONENT_TYPES.include?(normalized["type"])
  apply_battery_polarity!(normalized) if normalized["type"] == "battery"

  %w[x1 y1 x2 y2].each do |key|
    if normalized[key].nil?
      hint = diagonal_orientation?(normalized) ? "對角支路必須給兩個電氣接點，不能只給符號 bbox。" : ""
      raise "第 #{index + 1} 個元件缺少 #{key}。#{hint}"
    end

    normalized[key] = map_schema_coordinate(normalized[key], "元件 #{index + 1} 的 #{key}")
  end

  if normalized["type"] == "variable_resistor"
    unless normalized["wiper_x"].nil?
      normalized["wiper_x"] = map_schema_coordinate(normalized["wiper_x"], "元件 #{index + 1} 的 wiper_x")
    end
    unless normalized["wiper_y"].nil?
      normalized["wiper_y"] = map_schema_coordinate(normalized["wiper_y"], "元件 #{index + 1} 的 wiper_y")
    end
  end

  normalized["_index"] = index
  normalized
end

def endpoint_refs(components)
  refs = []
  components.each do |component|
    refs << [component, "x1", "y1"]
    refs << [component, "x2", "y2"]
    refs << [component, "wiper_x", "wiper_y"] if component["type"] == "variable_resistor"
  end
  refs
end

def coalesce_and_snap_endpoints!(components)
  refs = endpoint_refs(components)
  return components if refs.empty?

  points = refs.map { |component, x_key, y_key| [component[x_key].to_f, component[y_key].to_f] }
  parent = (0...points.length).to_a

  find = lambda do |index|
    parent[index] = find.call(parent[index]) if parent[index] != index
    parent[index]
  end
  union = lambda do |left, right|
    root_left = find.call(left)
    root_right = find.call(right)
    parent[root_right] = root_left unless root_left == root_right
  end

  points.each_index do |i|
    ((i + 1)...points.length).each do |j|
      next if Math.hypot(points[i][0] - points[j][0], points[i][1] - points[j][1]) > NODE_MERGE_RADIUS

      union.call(i, j)
    end
  end

  clusters = Hash.new { |hash, key| hash[key] = [] }
  points.each_index { |index| clusters[find.call(index)] << index }

  clusters.each_value do |members|
    mean_x = members.sum { |index| points[index][0] } / members.length
    mean_y = members.sum { |index| points[index][1] } / members.length
    snapped_x = snap_to_grid(mean_x)
    snapped_y = snap_to_grid(mean_y)
    members.each do |index|
      component, x_key, y_key = refs[index]
      component[x_key] = snapped_x
      component[y_key] = snapped_y
    end
  end

  components
end

def endpoint_degree_map(components)
  degrees = Hash.new(0)
  components.each do |component|
    component_end_points(component).each { |point| degrees[point] += 1 }
  end
  degrees
end

def unique_nodes(components)
  components.flat_map { |component| component_end_points(component) }.uniq
end

def already_connected?(components, first, second, except: nil)
  components.any? do |component|
    next false if component.equal?(except)
    next false unless UNORDERED_TWO_TERMINAL_TYPES.include?(component["type"]) || %w[battery switch ammeter voltmeter].include?(component["type"])

    ends = unordered_ends(component)
    ends == [first, second].sort
  end
end

def reattach_anchor_nodes(components, floating)
  anchored = components.reject do |component|
    floating.include?(component) || component["type"] == "wire"
  end
  unique_nodes(anchored)
end

def pair_alignment_cost(component, first, second)
  start_point = component_point(component, "x1", "y1")
  finish_point = component_point(component, "x2", "y2")
  aligned = Math.hypot(start_point[0] - first[0], start_point[1] - first[1]) +
            Math.hypot(finish_point[0] - second[0], finish_point[1] - second[1])
  swapped = Math.hypot(start_point[0] - second[0], start_point[1] - second[1]) +
            Math.hypot(finish_point[0] - first[0], finish_point[1] - first[1])
  [aligned, swapped].min
end

def best_reattach_pair(component, candidates)
  mx = (component["x1"] + component["x2"]) / 2.0
  my = (component["y1"] + component["y2"]) / 2.0
  length = [component_length(component), 1.0].max
  best = nil

  candidates.combination(2) do |first, second|
    span = Math.hypot(first[0] - second[0], first[1] - second[1])
    next if span < (2 * length)

    endpoint_distance = [
      point_to_segment_distance(component["x1"], component["y1"], first[0], first[1], second[0], second[1]),
      point_to_segment_distance(component["x2"], component["y2"], first[0], first[1], second[0], second[1])
    ].max
    midpoint_distance = point_to_segment_distance(mx, my, first[0], first[1], second[0], second[1])
    distance = [endpoint_distance, midpoint_distance].max
    next if distance > FLOATING_REATTACH_MAX_DISTANCE

    t = projection_t(mx, my, first[0], first[1], second[0], second[1])
    next unless t.between?(FLOATING_REATTACH_MIN_T, FLOATING_REATTACH_MAX_T)

    rank = [distance, pair_alignment_cost(component, first, second), -span, [first, second].sort]
    next if best && (rank <=> best[:rank]) >= 0

    assigned_first, assigned_second = aligned_reattach_ends(component, first, second)
    best = { first: assigned_first, second: assigned_second, rank: rank }
  end

  best
end

def aligned_reattach_ends(component, first, second)
  start_point = component_point(component, "x1", "y1")
  aligned = Math.hypot(start_point[0] - first[0], start_point[1] - first[1])
  swapped = Math.hypot(start_point[0] - second[0], start_point[1] - second[1])
  swapped < aligned ? [second, first] : [first, second]
end

def reattach_floating_components!(components)
  degrees = endpoint_degree_map(components)
  floating = components.select do |component|
    next false unless REATTACHABLE_TYPES.include?(component["type"])

    degrees[component_point(component, "x1", "y1")] == 1 && degrees[component_point(component, "x2", "y2")] == 1
  end
  return components if floating.empty?

  claimed = Hash.new { |hash, key| hash[key] = [] }
  assignments = []

  floating.each do |component|
    pair = best_reattach_pair(component, reattach_anchor_nodes(components, floating))
    next if pair.nil?
    next if already_connected?(components, pair[:first], pair[:second], except: component)

    key = [pair[:first], pair[:second]].sort
    claimed[key] << { component: component, pair: pair }
  end

  claimed.each_value do |group|
    next if group.length != 1

    choice = group.first
    assignments << choice
  end

  assignments.each do |choice|
    component = choice[:component]
    component["x1"], component["y1"] = choice[:pair][:first]
    component["x2"], component["y2"] = choice[:pair][:second]
  end

  components
end

def prune_useless_wires(components)
  non_wires = components.reject { |component| component["type"] == "wire" }
  return components if non_wires.empty?

  degrees = endpoint_degree_map(components)
  components.reject do |component|
    next false unless component["type"] == "wire"

    start_degree = degrees[component_point(component, "x1", "y1")]
    finish_degree = degrees[component_point(component, "x2", "y2")]
    start_degree < 2 || finish_degree < 2
  end
end

def split_wires_at_nodes(components)
  nodes = unique_nodes(components)
  split = []

  components.each do |component|
    unless component["type"] == "wire"
      split << component
      next
    end

    x1 = component["x1"]
    y1 = component["y1"]
    x2 = component["x2"]
    y2 = component["y2"]
    points = nodes.select do |px, py|
      ([px, py] == [x1, y1]) || ([px, py] == [x2, y2]) || point_on_segment?(px, py, x1, y1, x2, y2)
    end
    sorted = points.uniq.sort_by { |px, py| projection_t(px, py, x1, y1, x2, y2) }
    sorted.each_cons(2) do |(ax, ay), (bx, by)|
      next if ax == bx && ay == by

      split << component.merge("x1" => ax, "y1" => ay, "x2" => bx, "y2" => by)
    end
  end

  split
end

def drop_wires_that_short_components(components)
  spans = components.map do |component|
    next if component["type"] == "wire"

    unordered_ends(component)
  end.compact.uniq

  components.reject do |component|
    component["type"] == "wire" && spans.include?(unordered_ends(component))
  end
end

def drop_zero_length_wires(components)
  components.reject { |component| component["type"] == "wire" && zero_length?(component) }
end

def reject_zero_length_parts!(components)
  components.each do |component|
    next if component["type"] == "wire"
    next unless zero_length?(component)

    index = component["_index"].to_i + 1
    raise "第 #{index} 個元件（#{component["type"]}）兩端重疊，無法編譯。"
  end
end

def finalize_variable_resistors!(components)
  components.each do |component|
    next unless component["type"] == "variable_resistor"

    unless component["x1"] == component["x2"] || component["y1"] == component["y2"]
      index = component["_index"].to_i + 1
      raise "第 #{index} 個 variable_resistor 的主體必須保持水平或垂直。"
    end

    index = component["_index"].to_i + 1
    if component["y1"] == component["y2"]
      component["wiper_x"] = snap_to_grid(component["wiper_x"] || ((component["x1"] + component["x2"]) / 2.0))
      raise "第 #{index} 個 variable_resistor 缺少 wiper_y。" if component["wiper_y"].nil?

      component["wiper_y"] = snap_to_grid(component["wiper_y"])
    else
      raise "第 #{index} 個 variable_resistor 缺少 wiper_x。" if component["wiper_x"].nil?

      component["wiper_x"] = snap_to_grid(component["wiper_x"])
      component["wiper_y"] = snap_to_grid(component["wiper_y"] || ((component["y1"] + component["y2"]) / 2.0))
    end
  end
end

def dedupe_components(components)
  seen = {}
  components.reject do |component|
    key =
      if UNORDERED_TWO_TERMINAL_TYPES.include?(component["type"])
        [component["type"], unordered_ends(component), component["resistance"], component["voltage"]]
      else
        [component["type"], component["x1"], component["y1"], component["x2"], component["y2"], component["state"], component["voltage"]]
      end
    next true if seen[key]

    seen[key] = true
    false
  end
end

def circuit_bounds(components)
  xs = []
  ys = []
  components.each do |component|
    component_end_points(component).each do |x, y|
      xs << x
      ys << y
    end
  end
  return [0, 0, 0, 0] if xs.empty?

  [xs.min, ys.min, xs.max, ys.max]
end

def remap_axis(values, origin, scale)
  unique = values.uniq.sort
  mapping = {}
  unique.each do |value|
    mapping[value] = snap_to_grid(origin + ((value - origin) * scale))
  end

  previous = nil
  unique.each do |value|
    mapped = mapping[value]
    mapped = previous + GRID_SIZE if previous && mapped <= previous
    mapping[value] = mapped
    previous = mapped
  end
  mapping
end

def normalize_circuit_layout!(components)
  return components if components.empty?

  min_x, min_y, max_x, max_y = circuit_bounds(components)
  span = [max_x - min_x, max_y - min_y].max
  return components if span <= TARGET_LAYOUT_MAX

  scale = TARGET_LAYOUT_MAX.to_f / span
  refs = endpoint_refs(components)
  xs = refs.map { |component, x_key, _y_key| component[x_key] }
  ys = refs.map { |component, _x_key, y_key| component[y_key] }
  x_map = remap_axis(xs, min_x, scale)
  y_map = remap_axis(ys, min_y, scale)
  refs.each do |component, x_key, y_key|
    component[x_key] = x_map[component[x_key]]
    component[y_key] = y_map[component[y_key]]
  end
  components
end

def apply_circuit_topology_fixes(components)
  coalesce_and_snap_endpoints!(components)
  finalize_variable_resistors!(components)
  reattach_floating_components!(components)
  components = split_wires_at_nodes(components)
  components = drop_wires_that_short_components(components)
  components = drop_zero_length_wires(components)
  components = prune_useless_wires(components)
  reject_zero_length_parts!(components)
  components = dedupe_components(components)
  normalize_circuit_layout!(components)
  components
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

def switch_open?(component)
  raw = component["state"]
  return true if raw.nil?

  state = raw.to_s.strip.downcase
  return true if state.empty?
  return true if SWITCH_OPEN_STATES.include?(state)
  return false if SWITCH_CLOSED_STATES.include?(state)
  return state != "0" if state.match?(/\A\d+\z/)

  true
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
  position = switch_open?(component) ? 1 : 0
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

  parsed_components = components.each_with_index.map { |component, index| parse_schema_component(component, index) }
  normalized_components = apply_circuit_topology_fixes(parsed_components)
  raise "AI 沒有回傳任何可編譯的元件。" if normalized_components.empty?

  element_lines = normalized_components.map { |component| compile_course_component(component) }
  label_lines = normalized_components.flat_map { |component| build_component_label_lines(component) }

  ([FALSTAD_HEADER] + element_lines + label_lines).join("\n")
end
