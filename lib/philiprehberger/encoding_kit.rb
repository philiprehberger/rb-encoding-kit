# frozen_string_literal: true

require_relative 'encoding_kit/version'
require_relative 'encoding_kit/detection_result'
require_relative 'encoding_kit/detector'
require_relative 'encoding_kit/converter'

module Philiprehberger
  module EncodingKit
    class Error < StandardError; end

    # BOM signatures (re-exported for public use)
    BOMS = Detector::BOMS

    # Detect the encoding of a string via BOM and heuristics.
    # Returns a DetectionResult that delegates to the underlying Encoding,
    # so it can be compared directly (e.g., result == Encoding::UTF_8)
    # while also providing a confidence score via result.confidence.
    #
    # @param string [String] the input string
    # @return [DetectionResult] the detected encoding with confidence score
    def self.detect(string)
      Detector.call(string)
    end

    # Detect encoding from an IO stream by reading a sample of bytes.
    # The IO position is restored after reading (if the IO supports seek).
    #
    # @param io [IO, StringIO] the IO object to read from
    # @param sample_size [Integer] number of bytes to sample (default: 4096)
    # @return [DetectionResult] the detected encoding with confidence score
    def self.detect_stream(io, sample_size: 4096)
      original_pos = io.respond_to?(:pos) ? io.pos : nil
      sample = io.read(sample_size)

      if original_pos && io.respond_to?(:seek)
        io.seek(original_pos)
      end

      return DetectionResult.new(Encoding::BINARY, 0.5) if sample.nil? || sample.empty?

      Detector.call(sample)
    end

    # Analyze a string and return detailed byte distribution statistics
    # along with encoding candidates ranked by confidence.
    #
    # @param string [String] the input string
    # @return [Hash] analysis results with keys :encoding, :confidence,
    #   :printable_ratio, :ascii_ratio, :high_bytes, :candidates
    def self.analyze(string)
      bytes = string.b
      total = bytes.bytesize.to_f

      if total.zero?
        return {
          encoding: Encoding::BINARY,
          confidence: 0.5,
          printable_ratio: 0.0,
          ascii_ratio: 0.0,
          high_bytes: 0,
          candidates: [{ encoding: Encoding::BINARY, confidence: 0.5 }]
        }
      end

      ascii_count = 0
      printable_count = 0
      high_byte_count = 0

      bytes.each_byte do |b|
        ascii_count += 1 if b < 128
        printable_count += 1 if (0x20..0x7E).cover?(b) || b == 0x09 || b == 0x0A || b == 0x0D
        high_byte_count += 1 if b >= 128
      end

      primary = Detector.call(bytes)
      candidates = build_candidates(bytes, primary)

      {
        encoding: primary.encoding,
        confidence: primary.confidence,
        printable_ratio: (printable_count / total).round(4),
        ascii_ratio: (ascii_count / total).round(4),
        high_bytes: high_byte_count,
        candidates: candidates
      }
    end

    # Convert a string to UTF-8, auto-detecting source encoding if not specified.
    #
    # @param string [String] the input string
    # @param from [String, Encoding, nil] source encoding (auto-detect if nil)
    # @return [String] UTF-8 encoded string
    def self.to_utf8(string, from: nil)
      Converter.to_utf8(string, from: from)
    end

    # Normalize a string to valid UTF-8, replacing invalid/undefined bytes
    # with the Unicode replacement character (U+FFFD).
    #
    # @param string [String] the input string
    # @return [String] valid UTF-8 string
    def self.normalize(string)
      Converter.normalize(string)
    end

    # Check if a string is valid in the given encoding (or its current encoding).
    #
    # @param string [String] the input string
    # @param encoding [String, Encoding, nil] encoding to check against (defaults to string's encoding)
    # @return [Boolean]
    def self.valid?(string, encoding: nil)
      if encoding
        enc = Encoding.find(encoding.to_s)
        string.dup.force_encoding(enc).valid_encoding?
      else
        string.valid_encoding?
      end
    end

    # Convert a string between encodings.
    #
    # @param string [String] the input string
    # @param from [String, Encoding] source encoding
    # @param to [String, Encoding] target encoding
    # @return [String] the converted string
    def self.convert(string, from:, to:)
      Converter.convert(string, from: from, to: to)
    end

    # Transcode a string to the target encoding, auto-detecting the source.
    # Simpler API for the most common conversion pattern.
    #
    # @param string [String] the input string
    # @param to [String, Encoding] target encoding (default: UTF-8)
    # @param fallback [Symbol] fallback strategy (:replace or :raise)
    # @param replace [String] replacement character for invalid bytes
    # @return [String] the transcoded string
    # @raise [EncodingKit::Error] on conversion failure when fallback is :raise
    def self.transcode(string, to: Encoding::UTF_8, fallback: :replace, replace: '?')
      detected = Detector.call(string)
      source = detected.encoding
      target = to.is_a?(Encoding) ? to : Encoding.find(to.to_s)

      Converter.convert(string, from: source, to: target, fallback: fallback, replace: replace)
    end

    # Remove a byte order mark from the beginning of a string.
    #
    # @param string [String] the input string
    # @return [String] the string without a BOM
    def self.strip_bom(string)
      bytes = string.b
      BOMS.each do |bom, _encoding| # rubocop:disable Style/HashEachMethods
        if bytes.start_with?(bom)
          result = bytes[bom.bytesize..]
          return result.force_encoding(string.encoding)
        end
      end
      string.dup
    end

    # Check if a string starts with a byte order mark.
    #
    # @param string [String] the input string
    # @return [Boolean]
    def self.bom?(string)
      bytes = string.b
      BOMS.any? { |bom, _encoding| bytes.start_with?(bom) }
    end

    # Detect the encoding of a file by reading a byte sample.
    #
    # @param path [String] path to the file
    # @param sample_size [Integer] number of bytes to sample (default: 4096)
    # @return [DetectionResult] the detected encoding with confidence score
    def self.detect_file(path, sample_size: 4096)
      File.open(path, 'rb') do |file|
        detect_stream(file, sample_size: sample_size)
      end
    end

    # Read a file and return its content as UTF-8.
    # Auto-detects the source encoding unless specified via `from:`.
    #
    # @param path [String] path to the file
    # @param from [String, Encoding, nil] source encoding (auto-detect if nil)
    # @return [String] UTF-8 encoded file content
    def self.read_as_utf8(path, from: nil)
      raw = File.binread(path)
      to_utf8(raw, from: from)
    end

    # Check if a file's content is valid in the detected or specified encoding.
    #
    # @param path [String] path to the file
    # @param encoding [String, Encoding, nil] encoding to check against (auto-detect if nil)
    # @return [Boolean]
    def self.file_valid?(path, encoding: nil)
      raw = File.binread(path)
      valid?(raw, encoding: encoding)
    end

    # Build a list of encoding candidates with confidence scores.
    #
    # @param bytes [String] binary string
    # @param primary [DetectionResult] the primary detection result
    # @return [Array<Hash>] candidates sorted by confidence (descending)
    private_class_method def self.build_candidates(bytes, primary)
      candidates = [{ encoding: primary.encoding, confidence: primary.confidence }]

      # Check UTF-8 validity as a candidate
      utf8_dup = bytes.dup.force_encoding(Encoding::UTF_8)
      if utf8_dup.valid_encoding? && primary.encoding != Encoding::UTF_8
        candidates << { encoding: Encoding::UTF_8, confidence: 0.6 }
      end

      # Check ASCII as a candidate
      if bytes.each_byte.all? { |b| b < 128 } && primary.encoding != Encoding::US_ASCII
        candidates << { encoding: Encoding::US_ASCII, confidence: 0.5 }
      end

      # Always consider Latin-1 for high-byte content
      high_bytes = bytes.each_byte.any? { |b| b >= 128 }
      if high_bytes && primary.encoding != Encoding::ISO_8859_1
        candidates << { encoding: Encoding::ISO_8859_1, confidence: 0.5 }
      end

      # Consider Windows codepages for high-byte content
      if high_bytes
        has_control_high = bytes.each_byte.any? { |b| (0x80..0x9F).cover?(b) }
        if has_control_high && primary.encoding != Encoding::Windows_1252
          candidates << { encoding: Encoding::Windows_1252, confidence: 0.5 }
        end
      end

      candidates.sort_by { |c| -c[:confidence] }
    end
  end
end
