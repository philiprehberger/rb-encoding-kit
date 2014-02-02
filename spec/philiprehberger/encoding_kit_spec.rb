# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::EncodingKit do
  it 'has a version number' do
    expect(Philiprehberger::EncodingKit::VERSION).not_to be_nil
  end

  describe '.detect' do
    it 'detects plain ASCII as UTF-8 when valid UTF-8' do
      result = described_class.detect('hello world'.b)
      expect(result).to eq(Encoding::US_ASCII)
    end

    it 'detects UTF-8 with multibyte characters' do
      result = described_class.detect("caf\xC3\xA9".b)
      expect(result).to eq(Encoding::UTF_8)
    end

    it 'detects UTF-8 BOM' do
      bom_string = "\xEF\xBB\xBFhello".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_8)
    end

    it 'detects UTF-16 LE BOM' do
      bom_string = "\xFF\xFEh\x00i\x00".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_16LE)
    end

    it 'detects UTF-16 BE BOM' do
      bom_string = "\xFE\xFF\x00h\x00i".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_16BE)
    end

    it 'detects Latin-1 for high-byte content that is not valid UTF-8' do
      latin1_string = "caf\xE9".b
      result = described_class.detect(latin1_string)
      expect(result).to eq(Encoding::ISO_8859_1)
    end
  end

  describe '.to_utf8' do
    it 'converts Latin-1 to UTF-8' do
      latin1 = "caf\xE9".dup.force_encoding(Encoding::ISO_8859_1)
      result = described_class.to_utf8(latin1, from: Encoding::ISO_8859_1)
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result).to eq("caf\u00E9")
    end

    it 'auto-detects source encoding when from is nil' do
      utf8 = "hello \xC3\xA9".b
      result = described_class.to_utf8(utf8)
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
    end

    it 'replaces invalid bytes with replacement character' do
      bad = "\xFF\xFE".dup.force_encoding(Encoding::UTF_8)
      result = described_class.to_utf8(bad, from: Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
    end
  end

  describe '.normalize' do
    it 'returns valid UTF-8 unchanged' do
      input = 'hello world'
      result = described_class.normalize(input)
      expect(result).to eq('hello world')
      expect(result.encoding).to eq(Encoding::UTF_8)
    end

    it 'replaces invalid bytes with the replacement character' do
      bad = "hello \xFF world".b
      result = described_class.normalize(bad)
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
      expect(result).to include("\uFFFD")
    end

    it 'handles binary strings' do
      binary = "\x80\x81\x82".b
      result = described_class.normalize(binary)
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
    end
  end

  describe '.valid?' do
    it 'returns true for valid UTF-8' do
      expect(described_class.valid?("caf\u00E9")).to be true
    end

    it 'returns false for invalid UTF-8 bytes' do
      bad = "\xFF\xFE".dup.force_encoding(Encoding::UTF_8)
      expect(described_class.valid?(bad)).to be false
    end

    it 'checks against a specified encoding' do
      ascii = 'hello'
      expect(described_class.valid?(ascii, encoding: Encoding::US_ASCII)).to be true
    end

    it 'returns false when bytes are invalid for specified encoding' do
      high_bytes = "\x80\x81".b
      expect(described_class.valid?(high_bytes, encoding: Encoding::UTF_8)).to be false
    end
  end

  describe '.convert' do
    it 'converts between encodings' do
      utf8 = "caf\u00E9"
      result = described_class.convert(utf8, from: Encoding::UTF_8, to: Encoding::ISO_8859_1)
      expect(result.encoding).to eq(Encoding::ISO_8859_1)
      expect(result.bytes.to_a).to include(0xE9)
    end
  end

  describe '.strip_bom' do
    it 'removes UTF-8 BOM' do
      input = "\xEF\xBB\xBFhello".dup.force_encoding(Encoding::UTF_8)
      result = described_class.strip_bom(input)
      expect(result).to eq('hello')
    end

    it 'removes UTF-16 LE BOM' do
      input = "\xFF\xFEhello".b
      result = described_class.strip_bom(input)
      expect(result).to eq('hello'.b)
    end

    it 'returns the string unchanged when no BOM is present' do
      input = 'hello'
      result = described_class.strip_bom(input)
      expect(result).to eq('hello')
    end
  end

  describe '.bom?' do
    it 'returns true when a BOM is present' do
      expect(described_class.bom?("\xEF\xBB\xBFhello")).to be true
    end

    it 'returns false when no BOM is present' do
      expect(described_class.bom?('hello')).to be false
    end
  end
end
