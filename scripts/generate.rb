# frozen_string_literal: true

require 'json'
require 'yaml'

require_relative './lib/swedish_map'
script_dir = __dir__
input_path = File.join(script_dir, '..', 'config', 'keymap.json')
template_path = File.join(script_dir, '..', 'config', 'keymap_drawer.template.yaml')
output_path = File.join(script_dir, '..', 'config', 'keymap_drawer.yaml')

config = JSON.parse(File.read(input_path))

layers = config['layers']
flattened = layers.flatten
kps = flattened.select { |entry| entry['value'] == '&kp' }
non_kps = flattened.reject { |entry| entry['value'] == '&kp' }
ignored = %w[&trans &none]
unmapped = non_kps.reject { |entry| ignored.include?(entry['value']) }
device_tree = config['custom_devicetree']

def parse_zmk_modifier(mod)
  case mod
  when 'LSHFT', 'RSHFT', 'LS', 'RS' then :shift
  when 'LALT', 'RALT', 'LA', 'RA' then :alt
  when 'LCTRL', 'RCTRL', 'LC', 'RC' then :ctrl
  when 'LGUI', 'RGUI', 'LG', 'RG' then :gui
  end
end

def parse_keycode(definition, modifiers = [], zmk_modifiers = [])
  value = definition['value']
  params = definition['params']
  raise ArgumentError, "Expected only one param, got more: #{params.inspect}" if params.size > 1

  if params.empty?
    [value, modifiers, zmk_modifiers]
  elsif params.size == 1
    modifier = parse_zmk_modifier(value)
    raise ArgumentError, "Unknown modifier: #{value}" unless modifier

    parse_keycode(params.first, modifiers + [modifier], zmk_modifiers + [value])
  end
end

def find_swedish(keycode, modifiers)
  swedish_value = SWEDISH_MAP[keycode]

  return nil unless swedish_value

  if swedish_value.is_a?(String)
    return swedish_value if modifiers.empty?

    # No modifiers available for this keycode
    return nil
  elsif swedish_value.is_a?(Hash)
    _, v = swedish_value.find { |mods_key, _| mods_key.sort == modifiers.uniq.sort }
    return v if v
  end

  nil
end

# Keyboard Drawer wants keys like RA(A) or RA(RS(A))
def yaml_key(keycode, zmk_modifiers)
  if zmk_modifiers.empty?
    keycode
  else
    "#{zmk_modifiers.join('(')}(#{keycode})" + ')' * zmk_modifiers.size
  end
end

# Certain keys can be assumed to not need mappings, e.g. A-Z, F1-F12, TAB
def missing_ok?(keycode)
  a_to_z = ('A'..'Z').to_a
  modifier = parse_zmk_modifier(keycode)
  f_key = keycode.start_with?('F') && keycode[1..].to_i.between?(1, 12)

  a_to_z.include?(keycode) || keycode.start_with?('F') || modifier || f_key || keycode == 'TAB'
end

# Convert from a &kp definition to a Keyboard Drawer definition
def kp_to_definition(keycode, mods, zmk_mods)
  swedish = find_swedish(keycode, mods)
  shifted_swedish = find_swedish(keycode, mods + [:shift])
  if swedish.nil? && !missing_ok?(keycode)
    puts "Missing mapping for keycode #{keycode} with modifiers #{mods.inspect} (ZMK mods: #{zmk_mods.inspect})"
  else
    yaml_key = yaml_key(keycode, zmk_mods)
    { yaml_key => { 'tap' => swedish, 'shifted' => shifted_swedish }.reject { |_k, v| v.nil? } }
  end
end

# Build YAML entries for all &kp definitions that we have mappings for
zmk_keycode_map = kps
                  .map { |kp| parse_keycode(kp['params'].first) }
                  .map { |arr| kp_to_definition(*arr) }
                  .reject(&:nil?)
                  .reduce(:merge)
                  .reject { |_k, v| v.empty? }

puts "Number of unmapped entries: #{unmapped.size}"

# Scan the custom device tree for definitions like
# #define RED_RGB 0xFF0000
# #define RED &ug RED_RGB
device_tree_defs = device_tree.lines.each_with_object({}) do |line, acc|
  next unless line =~ /#define\s+(\S+)\s+(&\S+\s+)?(\S+)/

  name = Regexp.last_match(1)
  value = Regexp.last_match(3)

  acc[name] = if acc.key?(value)
                acc[value]
              else
                value
              end
end

# Scan the custom device tree for layers like
# #ifdef LAYER_BASE
#     bindings = < RED_RGB GREEN_RGB BLUE_RGB >
# #endif
# and extract the color definitions for each layer
device_tree_layers = device_tree.scan(/#ifdef LAYER_(\w+)(.*?)#endif/m).map do |match|
  layer_name = match[0]
  layer_body = match[1]
  bindings_match = layer_body.match(/bindings\s*=\s*<([^>]+)>;/m)
  next unless bindings_match

  bindings_text = bindings_match[1]
  bindings = bindings_text.lines.map do |line|
    line.strip.split(/\s+/).reject(&:empty?)
  end.flatten
  { layer_name => bindings }
end.compact.reduce(:merge)
puts device_tree_layers.inspect

css_for_colors = device_tree_layers.map do |layer, colors|
  colors.map.with_index.map do |color, idx|
    next unless device_tree_defs.key?(color)
    next if device_tree_defs[color] == '0x000000'

    color_hex = device_tree_defs[color]
    css_color = "##{color_hex[2..]}" # Remove '0x' prefix

    shifted_override = ".layer-#{layer} .keypos-#{idx} text.hold { fill: white; }" if color_hex != '0xFFFFFF'

    ".layer-#{layer} .keypos-#{idx} rect { fill: color-mix(in srgb, #{css_color} 70%, gray 30%); }\n#{shifted_override}"
  end
end

# Macro_name, default definition
hrm_passthroughs = %w[&HRM_left_index_tap_v1B_TKZ &HRM_left_middy_tap_v1B_TKZ &HRM_left_ring_tap_v1B_TKZ
                      &HRM_left_pinky_tap_v1B_TKZ &HRM_right_middy_tap_v1B_TKZ &HRM_right_pinky_tap_v1B_TKZ
                      &HRM_right_ring_tap_v1B_TKZ &HRM_right_pinky_tap_v1B_TKZ]
key_macros = { '&AS_v1_TKZ' => { 'type' => 'autoshift',
                                 'hold' => '$$mdi:apple-keyboard-shift$$' } }.merge(hrm_passthroughs.map do |m|
                                                                                      [m, { 'type' => 'passthrough' }]
                                                                                    end.to_h)

# Iterate through all the macros that are just "passthrough", so stuff like autoshift or HRM.
# They should display the same as regular keys except for the special behavior
key_macro_defs = unmapped.select { |u| key_macros.key?(u['value']) }.map do |entry|
  macro_name = entry['value']
  keycode, mods, zmk_mods = parse_keycode(entry['params'].first)
  definition = kp_to_definition(keycode, mods, zmk_mods).values.first
  definition = { 'tap' => keycode } if definition.nil? || definition.empty?
  yaml_key = "#{macro_name} #{yaml_key(keycode, zmk_mods)}"
  { yaml_key => definition.merge(key_macros[macro_name]) }
end.reduce(:merge)

template = YAML.load_file(template_path, aliases: true)
template['parse_config']['raw_binding_map'] = (template['parse_config']['raw_binding_map'] || {}).merge(key_macro_defs)
template['parse_config']['zmk_keycode_map'] = (template['parse_config']['zmk_keycode_map'] || {}).merge(zmk_keycode_map)
template['draw_config']['svg_extra_style'] =
  "#{template['draw_config']['svg_extra_style'] || ''}\n#{css_for_colors.flatten.compact.join("\n")}"
YAML.dump(template, File.open(output_path, 'w'))
