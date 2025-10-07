# frozen_string_literal: true

SWEDISH_MAP = {
  # Function keys are strings
  'F1' => 'F1',
  'F2' => 'F2',
  'F3' => 'F3',
  'F4' => 'F4',
  'F5' => 'F5',
  'F6' => 'F6',
  'F7' => 'F7',
  'F8' => 'F8',
  'F9' => 'F9',
  'F10' => 'F10',
  'F11' => 'F11',
  'F12' => 'F12',

  # Number row: base, Shift, Alt (Option), Alt+Shift
  'N1' => { [] => '1', [:shift] => '!' },
  'N2' => { [] => '2', [:shift] => '"', [:alt] => '@' },
  'N3' => { [] => '3', [:shift] => '#', [:alt] => '£' },
  'N4' => { [] => '4', [:shift] => '¤', [:alt] => '€' },
  'N5' => { [] => '5', [:shift] => '%' },
  'N6' => { [] => '6', [:shift] => '&' },
  'N7' => { [] => '7', [:shift] => '/', [:alt] => '|', %i[alt shift] => '\\' },
  'N8' => { [] => '8', [:shift] => '(', [:alt] => '[', %i[alt shift] => '{' },
  'N9' => { [] => '9', [:shift] => ')', [:alt] => ']', %i[alt shift] => '}' },
  'N0' => { [] => '0', [:shift] => 'EQ' },

  # Common punctuation / symbol keys
  'MINUS' => { [] => '+', [:shift] => '?', [:alt] => '±', %i[alt shift] => '¿' },
  'EQUAL' => { [] => '´', [:shift] => '`' },
  'NON_US_BSLH' => { [] => '<', [:shift] => '>' },
  'COMMA' => { [] => ',', [:shift] => ';' },
  'DOT' => { [] => '.', [:shift] => ':' },
  'FSLH' => { [] => '-', [:shift] => '_' },
  'BSLH' => { [] => "'", [:shift] => '*' },
  'GRAVE' => { [] => '<', [:shift] => '>' },
  'LBKT' => { [] => 'Å' },
  'RBKT' => { [] => '¨', [:shift] => '^', [:alt] => '~' },
  'SEMI' => { [] => 'Ö' },
  'SQT' => { [] => 'Ä' },

  # Utility symbols (simplified single-value entries)
  'PIPE' => '|',
  'PERCENT' => '%',
  'DLLR' => '$',
  'HASH' => '#',
  'EXCL' => '!',
  'PLUS' => '+',
  'UNDER' => '_',
  'LT' => { [] => '<?', [:alt] => '???' },
  'GT' => '>?',

  # Keypad
  'KP_N0' => '0',
  'KP_N1' => '1',
  'KP_N2' => '2',
  'KP_N3' => '3',
  'KP_N4' => '4',
  'KP_N5' => '5',
  'KP_N6' => '6',
  'KP_N7' => '7',
  'KP_N8' => '8',
  'KP_N9' => '9',
  'KP_DOT' => '.',
  'KP_EQUAL' => 'EQ',
  'KP_SLASH' => '/',
  'KP_MULTIPLY' => '*',
  'KP_PLUS' => '+',
  'KP_MINUS' => '-',

  'MACRO_PLACEHOLDER' => 'M'
}.freeze
