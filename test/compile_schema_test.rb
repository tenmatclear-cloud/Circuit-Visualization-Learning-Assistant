# frozen_string_literal: true

$stdout.sync = true

GRID_SIZE = 16
PHOTO_LAYOUT_ORIGIN_X = 96
PHOTO_LAYOUT_ORIGIN_Y = 64
PHOTO_LAYOUT_WIDTH = 384
PHOTO_LAYOUT_HEIGHT = 320
FALSTAD_HEADER = "$ 1 0.000005 10.20027730826997 42 12 43"
SUPPORTED_CIRCUIT_COMPONENT_TYPES = %w[
  wire battery resistor internal_resistance variable_resistor lamp switch ammeter voltmeter
].freeze

def normalize_component_type(raw_type)
  case raw_type.to_s.strip.downcase
  when "wire", "w" then "wire"
  when "battery", "cell", "voltage_source", "dc_voltage" then "battery"
  when "resistor", "load" then "resistor"
  when "internal_resistance", "inner_resistance", "battery_internal_resistance" then "internal_resistance"
  when "variable_resistor", "var_resistor", "pot", "potentiometer", "rheostat" then "variable_resistor"
  when "lamp", "bulb", "light_bulb" then "lamp"
  when "switch", "spst_switch" then "switch"
  when "ammeter", "current_meter" then "ammeter"
  when "voltmeter", "voltage_meter", "probe" then "voltmeter"
  else
    raw_type.to_s.strip.downcase
  end
end

require_relative "../circuit_schema_compiler"

$failures = 0

def fail_test(name, message)
  $failures += 1
  puts "FAIL #{name}: #{message}"
end

def pass_test(name)
  puts "PASS #{name}"
end

def dump_rows(code)
  code.lines.map(&:strip).reject { |line| line.empty? || line.start_with?("$") }.map { |line| line.split }
end

def resistors(code)
  dump_rows(code).select { |parts| parts[0] == "r" }.map do |parts|
    [[parts[1].to_i, parts[2].to_i], [parts[3].to_i, parts[4].to_i]]
  end
end

def wires(code)
  dump_rows(code).select { |parts| parts[0] == "w" }.map do |parts|
    [[parts[1].to_i, parts[2].to_i], [parts[3].to_i, parts[4].to_i]]
  end
end

def has_branch?(branches, first, second)
  ends = [first, second]
  branches.any? { |branch| branch.sort == ends.sort }
end

def dump_span(code)
  points = dump_rows(code).flat_map do |parts|
    [[parts[1].to_i, parts[2].to_i], [parts[3].to_i, parts[4].to_i]]
  end
  xs = points.map(&:first)
  ys = points.map(&:last)
  [xs.max - xs.min, ys.max - ys.min].max
end

def resistor_bbox_has_diagonal?(code)
  nodes = resistors(code).flatten(1)
  xs = nodes.map(&:first)
  ys = nodes.map(&:last)
  has_branch?(resistors(code), [xs.min, ys.min], [xs.max, ys.max])
end

def compile(components)
  compile_course_schema_to_falstad("components" => components)
end

def assert_true(name, value, detail = "")
  if value
    pass_test(name)
  else
    fail_test(name, detail)
  end
end

code = compile(
  [
    { "type" => "resistor", "x1" => 160, "y1" => 128, "x2" => 448, "y2" => 128 },
    { "type" => "resistor", "x1" => 448, "y1" => 128, "x2" => 448, "y2" => 256 },
    { "type" => "resistor", "x1" => 448, "y1" => 256, "x2" => 160, "y2" => 256 },
    { "type" => "resistor", "x1" => 160, "y1" => 256, "x2" => 160, "y2" => 128 },
    { "type" => "resistor", "x1" => 160, "y1" => 128, "x2" => 448, "y2" => 256, "orientation" => "diagonal" },
    { "type" => "wire", "x1" => 160, "y1" => 256, "x2" => 160, "y2" => 352 },
    { "type" => "switch", "x1" => 160, "y1" => 352, "x2" => 304, "y2" => 352, "state" => "open" },
    { "type" => "battery", "x1" => 448, "y1" => 352, "x2" => 304, "y2" => 352, "voltage" => 9 },
    { "type" => "wire", "x1" => 448, "y1" => 352, "x2" => 448, "y2" => 256 }
  ]
)
assert_true("preserve combine-3 diagonal", has_branch?(resistors(code), [160, 128], [448, 256]), code)
switch = dump_rows(code).find { |parts| parts[0] == "s" }
assert_true("combine-3 switch open", switch && switch[6] == "1", code)

code = compile(
  [
    { "type" => "resistor", "x1" => 192, "y1" => 128, "x2" => 816, "y2" => 128 },
    { "type" => "resistor", "x1" => 192, "y1" => 128, "x2" => 192, "y2" => 384 },
    { "type" => "resistor", "x1" => 816, "y1" => 128, "x2" => 816, "y2" => 384 },
    { "type" => "resistor", "x1" => 192, "y1" => 384, "x2" => 816, "y2" => 384 },
    { "type" => "resistor", "x1" => 448, "y1" => 240, "x2" => 560, "y2" => 240 },
    { "type" => "wire", "x1" => 560, "y1" => 272, "x2" => 816, "y2" => 272 },
    { "type" => "wire", "x1" => 192, "y1" => 384, "x2" => 192, "y2" => 624 },
    { "type" => "switch", "x1" => 192, "y1" => 624, "x2" => 400, "y2" => 624 },
    { "type" => "battery", "x1" => 688, "y1" => 624, "x2" => 624, "y2" => 624, "voltage" => 9 },
    { "type" => "wire", "x1" => 688, "y1" => 624, "x2" => 816, "y2" => 624 },
    { "type" => "wire", "x1" => 816, "y1" => 384, "x2" => 816, "y2" => 624 }
  ]
)
assert_true("reattach floating bridge to TL-BR", resistor_bbox_has_diagonal?(code), code)
assert_true("remove floating symbol resistor", resistors(code).length == 5, code)
assert_true("drop dangling diagonal stub wire", !has_branch?(wires(code), [560, 272], [816, 272]), code)
assert_true("shrink oversized bridge layout", dump_span(code) <= TARGET_LAYOUT_MAX + GRID_SIZE, "span=#{dump_span(code)} #{code}")

code = compile(
  [
    { "type" => "resistor", "x1" => 160, "y1" => 128, "x2" => 160, "y2" => 208 },
    { "type" => "resistor", "x1" => 320, "y1" => 128, "x2" => 320, "y2" => 208 },
    { "type" => "resistor", "x1" => 240, "y1" => 208, "x2" => 240, "y2" => 288 },
    { "type" => "wire", "x1" => 160, "y1" => 128, "x2" => 320, "y2" => 128 },
    { "type" => "wire", "x1" => 240, "y1" => 128, "x2" => 240, "y2" => 208 }
  ]
)
assert_true("split removes unsplit through wire", !has_branch?(wires(code), [160, 128], [320, 128]), code)
assert_true("split left half", has_branch?(wires(code), [160, 128], [240, 128]), code)
assert_true("split right half", has_branch?(wires(code), [240, 128], [320, 128]), code)
assert_true("keep T-junction branch", has_branch?(wires(code), [240, 128], [240, 208]), code)

code = compile(
  [
    { "type" => "resistor", "x1" => 160, "y1" => 128, "x2" => 320, "y2" => 128 },
    { "type" => "wire", "x1" => 160, "y1" => 128, "x2" => 320, "y2" => 128 },
    { "type" => "battery", "x1" => 160, "y1" => 192, "x2" => 160, "y2" => 128, "voltage" => 9 },
    { "type" => "wire", "x1" => 320, "y1" => 128, "x2" => 320, "y2" => 192 },
    { "type" => "wire", "x1" => 320, "y1" => 192, "x2" => 160, "y2" => 192 }
  ]
)
assert_true("drop shorting wire", !has_branch?(wires(code), [160, 128], [320, 128]), code)
assert_true("keep resistor under shorting wire", has_branch?(resistors(code), [160, 128], [320, 128]), code)

code = compile(
  [
    { "type" => "resistor", "x1" => 161, "y1" => 129, "x2" => 320, "y2" => 129 },
    { "type" => "wire", "x1" => 158, "y1" => 130, "x2" => 160, "y2" => 256 },
    { "type" => "battery", "x1" => 160, "y1" => 256, "x2" => 320, "y2" => 256, "voltage" => 9 },
    { "type" => "wire", "x1" => 320, "y1" => 256, "x2" => 320, "y2" => 128 }
  ]
)
assert_true("coalesce nearby resistor end", has_branch?(resistors(code), [160, 128], [320, 128]), code)
assert_true("coalesce nearby wire onto same node", wires(code).any? { |branch| branch.include?([160, 128]) }, code)

code = compile(
  [
    { "type" => "switch", "x1" => 160, "y1" => 192, "x2" => 256, "y2" => 192 },
    { "type" => "battery", "x1" => 256, "y1" => 192, "x2" => 256, "y2" => 128, "voltage" => 9 },
    { "type" => "resistor", "x1" => 256, "y1" => 128, "x2" => 160, "y2" => 128 },
    { "type" => "wire", "x1" => 160, "y1" => 128, "x2" => 160, "y2" => 192 }
  ]
)
switch = dump_rows(code).find { |parts| parts[0] == "s" }
assert_true("switch defaults to open", switch && switch[6] == "1", code)

code = compile(
  [
    { "type" => "switch", "x1" => 160, "y1" => 192, "x2" => 256, "y2" => 192, "state" => "closed" },
    { "type" => "battery", "x1" => 256, "y1" => 192, "x2" => 256, "y2" => 128, "voltage" => 9 },
    { "type" => "resistor", "x1" => 256, "y1" => 128, "x2" => 160, "y2" => 128 },
    { "type" => "wire", "x1" => 160, "y1" => 128, "x2" => 160, "y2" => 192 }
  ]
)
switch = dump_rows(code).find { |parts| parts[0] == "s" }
assert_true("closed switch stays closed", switch && switch[6] == "0", code)

code = compile(
  [
    { "type" => "resistor", "x1" => 192, "y1" => 128, "x2" => 192, "y2" => 256 },
    { "type" => "resistor", "x1" => 448, "y1" => 128, "x2" => 448, "y2" => 256 },
    { "type" => "resistor", "x1" => 224, "y1" => 128, "x2" => 288, "y2" => 128 },
    { "type" => "resistor", "x1" => 352, "y1" => 128, "x2" => 416, "y2" => 128 }
  ]
)
assert_true("do not stretch two series resistors", !has_branch?(resistors(code), [192, 128], [448, 128]), code)
assert_true("keep first series resistor", has_branch?(resistors(code), [224, 128], [288, 128]), code)
assert_true("keep second series resistor", has_branch?(resistors(code), [352, 128], [416, 128]), code)

begin
  compile(
    [
      {
        "type" => "resistor",
        "orientation" => "diagonal",
        "bbox" => [448, 240, 560, 256]
      }
    ]
  )
  fail_test("diagonal bbox without terminals", "expected error")
rescue RuntimeError => error
  assert_true("diagonal bbox without terminals", error.message =~ /缺少 x1|電氣接點/, error.message)
end

code = compile(
  [
    { "type" => "variable_resistor", "x1" => 160, "y1" => 128, "x2" => 320, "y2" => 128, "wiper_y" => 176 },
    { "type" => "battery", "x1" => 160, "y1" => 192, "x2" => 160, "y2" => 128, "voltage" => 9 },
    { "type" => "wire", "x1" => 320, "y1" => 128, "x2" => 320, "y2" => 192 },
    { "type" => "wire", "x1" => 320, "y1" => 192, "x2" => 160, "y2" => 192 }
  ]
)
pot = dump_rows(code).find { |parts| parts[0] == "174" }
assert_true("compile variable resistor", pot && pot[1] == "160" && pot[2] == "128", code)

if $failures.zero?
  puts "All tests passed."
  exit 0
end

puts "#{$failures} failure(s)"
exit 1
