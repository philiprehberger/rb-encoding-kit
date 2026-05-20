# frozen_string_literal: true

module Philiprehberger
  module EncodingKit
    # Encoding conversion with fallback handling
    module Converter
      class << self
        # Convert a string from one encoding to another.
        #
        # @param string [String] the input string
        # @param from [String, Encoding] source encoding
        # @param to [String, Encoding] target encoding
        # @param fallback [Symbol] fallback strategy (:replace or :raise)
        # @param replace [String] replacement character for invalid bytes
        # @return [String] the converted string
        # @raise [EncodingKit::Error] on conversion failure when fallback is :raise
        def convert(string, from:, to:, fallback: :replace, replace: '?')
          source = Encoding.find(from.to_s)
          target = Encoding.find(to.to_s)

          str = string.dup.force_encoding(source)

          if fallback == :replace
            str.encode(target, invalid: :replace, undef: :replace, replace: replace)
          else
            str.encode(target)
          end
        rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
          raise Error, "Encoding conversion failed: #{e.message}"
        end

        # Convert a string to UTF-8, optionally auto-detecting the source encoding.
        #
        # @param string [String] the input string
        # @param from [String, Encoding, nil] source encoding (auto-detect if nil)
        # @param strip_bom [Boolean] remove any leading UTF BOM from the result (default: false)
        # @return [String] UTF-8 encoded string
        def to_utf8(string, from: nil, strip_bom: false)
          detected = from ? Encoding.find(from.to_s) : Detector.call(string)
          source = detected.is_a?(DetectionResult) ? detected.encoding : detected
          str = string.dup.force_encoding(source)
          encoded = str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
          strip_bom ? encoded.delete_prefix("\uFEFF") : encoded
        end

        # Force a string to valid UTF-8 by replacing invalid and undefined bytes.
        #
        # @param string [String] the input string
        # @return [String] valid UTF-8 string with replacement characters for bad bytes
        def normalize(string)
          str = string.dup
          str.force_encoding(Encoding::UTF_8) if [Encoding::BINARY, Encoding::ASCII_8BIT].include?(str.encoding)

          return str if str.encoding == Encoding::UTF_8 && str.valid_encoding?

          str.encode(Encoding::UTF_8, str.encoding, invalid: :replace, undef: :replace, replace: "\uFFFD")
        end

        # Strip invalid bytes from a string, returning valid UTF-8 with bad bytes removed.
        #
        # Unlike {.normalize}, which replaces invalid bytes with `\uFFFD`, this method
        # removes them entirely \u2014 useful when downstream consumers cannot tolerate
        # any non-source content.
        #
        # @param string [String] the input string
        # @return [String] valid UTF-8 string with invalid bytes removed
        def scrub(string)
          str = string.dup
          str.force_encoding(Encoding::UTF_8) if [Encoding::BINARY, Encoding::ASCII_8BIT].include?(str.encoding)
          str.scrub('')
        end
      end
    end
  end
end
