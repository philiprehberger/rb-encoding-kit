# frozen_string_literal: true

module Philiprehberger
  module EncodingKit
    # Encoding detection via BOM inspection and byte-pattern heuristics
    module Detector
      # BOM signatures ordered from longest to shortest to avoid false matches
      BOMS = [
        ["\x00\x00\xFE\xFF".b, Encoding::UTF_32BE],
        ["\xFF\xFE\x00\x00".b, Encoding::UTF_32LE],
        ["\xEF\xBB\xBF".b, Encoding::UTF_8],
        ["\xFE\xFF".b,         Encoding::UTF_16BE],
        ["\xFF\xFE".b,         Encoding::UTF_16LE]
      ].freeze

      class << self
        # Detect the encoding of a byte string.
        #
        # Strategy:
        #   1. Check for a byte order mark (BOM)
        #   2. Try UTF-8 validity
        #   3. Check pure ASCII
        #   4. Apply Latin-1 heuristic
        #   5. Fall back to BINARY
        #
        # @param string [String] the input string (ideally with BINARY/ASCII-8BIT encoding)
        # @return [Encoding] the detected encoding
        def call(string)
          bytes = string.b

          bom_encoding = detect_bom(bytes)
          return bom_encoding if bom_encoding

          return Encoding::UTF_8 if valid_utf8?(bytes)
          return Encoding::US_ASCII if ascii_only?(bytes)
          return Encoding::ISO_8859_1 if latin1_heuristic?(bytes)

          Encoding::BINARY
        end

        # Check whether the string starts with a known BOM.
        #
        # @param bytes [String] binary string
        # @return [Encoding, nil] the encoding indicated by the BOM, or nil
        def detect_bom(bytes)
          BOMS.each do |bom, encoding|
            return encoding if bytes.start_with?(bom)
          end
          nil
        end

        private

        # @param bytes [String] binary string
        # @return [Boolean]
        def valid_utf8?(bytes)
          dup = bytes.dup.force_encoding(Encoding::UTF_8)
          dup.valid_encoding? && !ascii_only?(bytes)
        end

        # @param bytes [String] binary string
        # @return [Boolean]
        def ascii_only?(bytes)
          bytes.each_byte.all? { |b| b < 128 }
        end

        # Simple heuristic: if every byte is in the ISO-8859-1 printable range
        # (0x20..0x7E or 0xA0..0xFF) or is a common control character, treat as Latin-1.
        #
        # @param bytes [String] binary string
        # @return [Boolean]
        def latin1_heuristic?(bytes)
          bytes.each_byte.all? do |b|
            (0x20..0x7E).cover?(b) || (0xA0..0xFF).cover?(b) ||
              b == 0x09 || b == 0x0A || b == 0x0D # tab, LF, CR
          end
        end
      end
    end
  end
end
