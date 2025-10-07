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

  if params.empty?
    [value, modifiers, zmk_modifiers]
  elsif params.size == 1
    modifier = parse_zmk_modifier(value)
    raise ArgumentError, "Unknown modifier: #{value}" unless modifier

    parse_keycode(params.first, modifiers + [modifier], zmk_modifiers + [value])
  else
    raise ArgumentError, "Expected only one param, got more: #{params.inspect}"
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

def yaml_key(keycode, zmk_modifiers)
  if zmk_modifiers.empty?
    keycode
  else
    "#{zmk_modifiers.join('(')}(#{keycode})" + ')' * zmk_modifiers.size
  end
end

def missing_ok?(keycode)
  a_to_z = ('A'..'Z').to_a
  modifier = parse_zmk_modifier(keycode)
  f_key = keycode.start_with?('F') && keycode[1..].to_i.between?(1, 12)

  a_to_z.include?(keycode) || keycode.start_with?('F') || modifier || f_key || keycode == 'TAB'
end

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

zmk_keycode_map = kps
                  .map { |kp| parse_keycode(kp['params'].first) }
                  .map { |arr| kp_to_definition(*arr) }
                  .reject(&:nil?)
                  .reduce(:merge)
                  .reject { |_k, v| v.empty? }

puts "Number of unmapped entries: #{unmapped.size}"

# Macro_name, default definition
hrm_passthroughs = %w[&HRM_left_index_tap_v1B_TKZ &HRM_left_middy_tap_v1B_TKZ &HRM_left_ring_tap_v1B_TKZ
                      &HRM_left_pinky_tap_v1B_TKZ &HRM_right_middy_tap_v1B_TKZ &HRM_right_pinky_tap_v1B_TKZ
                      &HRM_right_ring_tap_v1B_TKZ &HRM_right_pinky_tap_v1B_TKZ]
key_macros = { '&AS_v1_TKZ' => { 'type' => 'autoshift',
                                 'hold' => '$$mdi:apple-keyboard-shift$$' } }.merge(hrm_passthroughs.map do |m|
                                                                                      [m, { 'type' => 'passthrough' }]
                                                                                    end.to_h)

key_macro_defs = unmapped.select { |u| key_macros.key?(u['value']) }.map do |entry|
  macro_name = entry['value']
  keycode, mods, zmk_mods = parse_keycode(entry['params'].first)
  definition = kp_to_definition(keycode, mods, zmk_mods).values.first
  definition = { 'tap' => keycode } if definition.nil? || definition.empty?
  yaml_key = "#{macro_name} #{yaml_key(keycode, zmk_mods)}"
  { yaml_key => definition.merge(key_macros[macro_name]) }
end.reduce(:merge)

# puts key_macro_defs.to_yaml
template = YAML.load_file(template_path, aliases: true)
template['parse_config']['raw_binding_map'] = (template['parse_config']['raw_binding_map'] || {}).merge(key_macro_defs)
template['parse_config']['zmk_keycode_map'] = (template['parse_config']['zmk_keycode_map'] || {}).merge(zmk_keycode_map)
YAML.dump(template, File.open(output_path, 'w'))
