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

      # Bytes in 0x80-0x9F that are defined in CP1252 but not in ISO-8859-1.
      # These bytes are unmapped in ISO-8859-1, so their presence strongly
      # suggests a Windows codepage.
      CP1252_SPECIFIC = [
        0x80, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88,
        0x89, 0x8A, 0x8B, 0x8C, 0x8E, 0x91, 0x92, 0x93,
        0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B,
        0x9C, 0x9E, 0x9F
      ].freeze

      # CP1250 (Central European) has specific characters in 0x80-0x9F
      # that differ from CP1252. Common: 0x8A (S-caron), 0x8E (Z-caron),
      # 0x9A (s-caron), 0x9E (z-caron).
      CP1250_MARKERS = [0x8A, 0x8E, 0x9A, 0x9E].freeze

      # CP1251 (Cyrillic) maps 0x80-0xFF almost entirely to Cyrillic letters.
      # Bytes 0xC0-0xFF are Cyrillic А-я in CP1251.
      CP1251_RANGE = (0xC0..0xFF)

      class << self
        # Detect the encoding of a byte string, returning a DetectionResult
        # with encoding and confidence score.
        #
        # Strategy:
        #   1. Check for a byte order mark (BOM) - confidence 1.0
        #   2. Try UTF-8 validity - confidence 0.9
        #   3. Check pure ASCII - confidence 0.9
        #   4. Check Windows codepages (CP1252, CP1250, CP1251) - confidence 0.6-0.7
        #   5. Apply Latin-1 heuristic - confidence 0.7
        #   6. Fall back to BINARY - confidence 0.5
        #
        # @param string [String] the input string (ideally with BINARY/ASCII-8BIT encoding)
        # @return [DetectionResult] the detected encoding with confidence
        def call(string)
          bytes = string.b

          bom_result = detect_bom_with_confidence(bytes)
          return bom_result if bom_result

          return DetectionResult.new(Encoding::UTF_8, utf8_confidence(bytes)) if valid_utf8?(bytes)
          return DetectionResult.new(Encoding::US_ASCII, 0.9) if ascii_only?(bytes)

          codepage_result = detect_windows_codepage(bytes)
          return codepage_result if codepage_result

          return DetectionResult.new(Encoding::ISO_8859_1, 0.7) if latin1_heuristic?(bytes)

          DetectionResult.new(Encoding::BINARY, 0.5)
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

        # Detect BOM and return a DetectionResult with confidence 1.0.
        #
        # @param bytes [String] binary string
        # @return [DetectionResult, nil]
        def detect_bom_with_confidence(bytes)
          BOMS.each do |bom, encoding|
            return DetectionResult.new(encoding, 1.0) if bytes.start_with?(bom)
          end
          nil
        end

        # Calculate UTF-8 confidence based on the ratio of multibyte sequences.
        #
        # @param bytes [String] binary string
        # @return [Float] confidence between 0.8 and 0.9
        def utf8_confidence(bytes)
          total = bytes.bytesize.to_f
          return 0.9 if total.zero?

          high_bytes = bytes.each_byte.count { |b| b >= 128 }
          ratio = high_bytes / total

          # More multibyte chars = higher confidence it's genuinely UTF-8
          ratio > 0.1 ? 0.9 : 0.85
        end

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

        # Detect Windows codepages by checking for bytes in the 0x80-0x9F range.
        #
        # @param bytes [String] binary string
        # @return [DetectionResult, nil]
        def detect_windows_codepage(bytes)
          high_control = bytes.each_byte.grep(0x80..0x9F)
          return nil if high_control.empty?

          # Check for CP1251 (Cyrillic): high ratio of bytes in 0xC0-0xFF
          cyrillic_count = bytes.each_byte.count { |b| CP1251_RANGE.cover?(b) }
          total_high = bytes.each_byte.count { |b| b >= 0x80 }

          if total_high.positive? && (cyrillic_count.to_f / total_high) > 0.6
            return DetectionResult.new(Encoding::Windows_1251, 0.65)
          end

          # Check for CP1250 (Central European): presence of specific marker bytes
          cp1250_markers = high_control.count { |b| CP1250_MARKERS.include?(b) }
          if cp1250_markers >= 2
            return DetectionResult.new(Encoding::Windows_1250, 0.6)
          end

          # Default to CP1252 (Western European) if bytes in 0x80-0x9F are present
          cp1252_count = high_control.count { |b| CP1252_SPECIFIC.include?(b) }
          if cp1252_count.positive?
            confidence = cp1252_count > 3 ? 0.7 : 0.6
            return DetectionResult.new(Encoding::Windows_1252, confidence)
          end

          nil
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
