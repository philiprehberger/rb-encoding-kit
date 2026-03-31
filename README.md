# philiprehberger-encoding_kit

[![Tests](https://github.com/philiprehberger/rb-encoding-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-encoding-kit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-encoding_kit.svg)](https://rubygems.org/gems/philiprehberger-encoding_kit)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-encoding-kit)](https://github.com/philiprehberger/rb-encoding-kit/commits/main)

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

result = Philiprehberger::EncodingKit.detect(raw_bytes)
result.encoding   # => Encoding::UTF_8
result.confidence # => 0.9
utf8 = Philiprehberger::EncodingKit.to_utf8(raw_bytes)
```

### Encoding Detection with Confidence

```ruby
require "philiprehberger/encoding_kit"

# Returns a DetectionResult that delegates to Encoding
result = Philiprehberger::EncodingKit.detect("\xEF\xBB\xBFhello".b)
result == Encoding::UTF_8  # => true (backward compatible)
result.confidence          # => 1.0 (BOM detected)
result.name                # => "UTF-8"
result.to_h                # => {encoding: Encoding::UTF_8, confidence: 1.0}

# Heuristic detection returns lower confidence
result = Philiprehberger::EncodingKit.detect("caf\xC3\xA9".b)
result.confidence # => 0.85-0.9
```

### Streaming Detection

```ruby
require "philiprehberger/encoding_kit"

File.open("data.csv", "rb") do |file|
  result = Philiprehberger::EncodingKit.detect_stream(file, sample_size: 8192)
  result.encoding   # => Encoding::UTF_8
  result.confidence # => 0.9
end
```

### Encoding Analysis

```ruby
require "philiprehberger/encoding_kit"

analysis = Philiprehberger::EncodingKit.analyze(raw_bytes)
analysis[:encoding]       # => Encoding::UTF_8
analysis[:confidence]     # => 0.9
analysis[:printable_ratio] # => 0.95
analysis[:ascii_ratio]    # => 0.8
analysis[:high_bytes]     # => 12
analysis[:candidates]     # => [{encoding: Encoding::UTF_8, confidence: 0.9}, ...]
```

### Transcode

```ruby
require "philiprehberger/encoding_kit"

# Auto-detect source, convert to UTF-8
utf8 = Philiprehberger::EncodingKit.transcode(raw_bytes)

# Convert to a specific encoding
latin1 = Philiprehberger::EncodingKit.transcode(utf8_string, to: Encoding::ISO_8859_1)

# Custom fallback behavior
result = Philiprehberger::EncodingKit.transcode(data, to: "UTF-8", fallback: :replace, replace: "?")
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
| `EncodingKit.detect(string)` | Detect encoding via BOM and heuristics, returns a `DetectionResult` with `.encoding` and `.confidence` |
| `EncodingKit.detect_stream(io, sample_size: 4096)` | Detect encoding from an IO stream by sampling bytes |
| `EncodingKit.analyze(string)` | Analyze byte distribution and return encoding candidates with stats |
| `EncodingKit.transcode(string, to:, fallback:, replace:)` | Auto-detect source and convert to target encoding |
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

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-encoding-kit)

🐛 [Report issues](https://github.com/philiprehberger/rb-encoding-kit/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-encoding-kit/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
