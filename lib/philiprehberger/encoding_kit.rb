# frozen_string_literal: true

require_relative 'encoding_kit/version'
require_relative 'encoding_kit/detector'
require_relative 'encoding_kit/converter'

module Philiprehberger
  module EncodingKit
    class Error < StandardError; end

    # BOM signatures (re-exported for public use)
    BOMS = Detector::BOMS

    # Detect the encoding of a string via BOM and heuristics.
    #
    # @param string [String] the input string
    # @return [Encoding] the detected encoding
    def self.detect(string)
      Detector.call(string)
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
  end
end
