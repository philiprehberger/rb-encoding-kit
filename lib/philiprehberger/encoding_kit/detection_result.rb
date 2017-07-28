# frozen_string_literal: true

module Philiprehberger
  module EncodingKit
    # A detection result that wraps an Encoding with a confidence score.
    # Delegates to the underlying Encoding so it can be used transparently
    # wherever an Encoding object is expected (e.g., == Encoding::UTF_8).
    class DetectionResult
      attr_reader :encoding, :confidence

      # @param encoding [Encoding] the detected encoding
      # @param confidence [Float] confidence score between 0.0 and 1.0
      def initialize(encoding, confidence)
        @encoding = encoding
        @confidence = confidence.to_f
      end

      # Equality check delegates to the underlying encoding so that
      # `result == Encoding::UTF_8` works as expected.
      #
      # @param other [Object] the object to compare
      # @return [Boolean]
      def ==(other)
        case other
        when Encoding
          @encoding == other
        when DetectionResult
          @encoding == other.encoding
        else
          super
        end
      end

      # Support `eql?` for hash key usage.
      #
      # @param other [Object]
      # @return [Boolean]
      def eql?(other)
        self == other
      end

      # Delegate hash to encoding for hash key consistency.
      #
      # @return [Integer]
      def hash
        @encoding.hash
      end

      # String representation shows the encoding name.
      #
      # @return [String]
      def to_s
        @encoding.to_s
      end

      # Inspect shows both encoding and confidence.
      #
      # @return [String]
      def inspect
        "#<#{self.class} encoding=#{@encoding} confidence=#{@confidence}>"
      end

      # Convert to a plain hash representation.
      #
      # @return [Hash]
      def to_h
        { encoding: @encoding, confidence: @confidence }
      end

      # Delegate unknown methods to the underlying Encoding object.
      def method_missing(method, ...)
        if @encoding.respond_to?(method)
          @encoding.send(method, ...)
        else
          super
        end
      end

      # Support respond_to? for delegated methods.
      def respond_to_missing?(method, include_private = false)
        @encoding.respond_to?(method, include_private) || super
      end
    end
  end
end
