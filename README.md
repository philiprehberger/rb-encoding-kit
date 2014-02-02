# philiprehberger-encoding_kit

[![Tests](https://github.com/philiprehberger/rb-encoding-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-encoding-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-encoding_kit.svg)](https://rubygems.org/gems/philiprehberger-encoding_kit)
[![License](https://img.shields.io/github/license/philiprehberger/rb-encoding-kit)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Character encoding detection, conversion, and normalization

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-encoding_kit"
```

Or install directly:

```bash
gem install philiprehberger-encoding_kit
```

## Usage

```ruby
require "philiprehberger/encoding_kit"

encoding = Philiprehberger::EncodingKit.detect(raw_bytes)
utf8 = Philiprehberger::EncodingKit.to_utf8(raw_bytes)
```

### Encoding Detection

```ruby
require "philiprehberger/encoding_kit"

# Detects via BOM first, then UTF-8 validity, ASCII, Latin-1 heuristics
Philiprehberger::EncodingKit.detect("\xEF\xBB\xBFhello".b) # => Encoding::UTF_8
Philiprehberger::EncodingKit.detect("caf\xC3\xA9".b)       # => Encoding::UTF_8
Philiprehberger::EncodingKit.detect("caf\xE9".b)            # => Encoding::ISO_8859_1
```

### Convert to UTF-8

```ruby
require "philiprehberger/encoding_kit"

# Auto-detect source encoding
utf8 = Philiprehberger::EncodingKit.to_utf8(raw_bytes)

# Specify source encoding
utf8 = Philiprehberger::EncodingKit.to_utf8(latin1_string, from: Encoding::ISO_8859_1)
```

### Normalize

```ruby
require "philiprehberger/encoding_kit"

# Replace invalid/undefined bytes with U+FFFD
clean = Philiprehberger::EncodingKit.normalize("hello \xFF world".b)
```

### Convert Between Encodings

```ruby
require "philiprehberger/encoding_kit"

latin1 = Philiprehberger::EncodingKit.convert(utf8_string, from: Encoding::UTF_8, to: Encoding::ISO_8859_1)
```

### BOM Handling

```ruby
require "philiprehberger/encoding_kit"

Philiprehberger::EncodingKit.bom?("\xEF\xBB\xBFhello")       # => true
Philiprehberger::EncodingKit.strip_bom("\xEF\xBB\xBFhello")  # => "hello"
```

### Validity Check

```ruby
require "philiprehberger/encoding_kit"

Philiprehberger::EncodingKit.valid?("hello")                                # => true
Philiprehberger::EncodingKit.valid?("\xFF\xFE".force_encoding("UTF-8"))     # => false
Philiprehberger::EncodingKit.valid?("hello", encoding: Encoding::US_ASCII)  # => true
```

## API

| Method | Description |
|--------|-------------|
| `EncodingKit.detect(string)` | Detect encoding via BOM and heuristics, returns an `Encoding` object |
| `EncodingKit.to_utf8(string, from: nil)` | Convert to UTF-8, auto-detect source if `from` is nil |
| `EncodingKit.normalize(string)` | Force to valid UTF-8, replacing bad bytes with U+FFFD |
| `EncodingKit.valid?(string, encoding: nil)` | Check if string is valid in given or current encoding |
| `EncodingKit.convert(string, from:, to:)` | Convert between arbitrary encodings |
| `EncodingKit.strip_bom(string)` | Remove byte order mark if present |
| `EncodingKit.bom?(string)` | Check if string starts with a BOM |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

[MIT](LICENSE)
