# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tempfile'

RSpec.describe Philiprehberger::EncodingKit do
  it 'has a version number' do
    expect(Philiprehberger::EncodingKit::VERSION).not_to be_nil
  end

  describe '.detect' do
    it 'returns a DetectionResult' do
      result = described_class.detect('hello world'.b)
      expect(result).to be_a(Philiprehberger::EncodingKit::DetectionResult)
    end

    it 'detects plain ASCII as US-ASCII' do
      result = described_class.detect('hello world'.b)
      expect(result).to eq(Encoding::US_ASCII)
      expect(result.confidence).to eq(0.9)
    end

    it 'detects UTF-8 with multibyte characters' do
      result = described_class.detect("caf\xC3\xA9".b)
      expect(result).to eq(Encoding::UTF_8)
      expect(result.confidence).to be_between(0.8, 0.9)
    end

    it 'detects UTF-8 BOM with confidence 1.0' do
      bom_string = "\xEF\xBB\xBFhello".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_8)
      expect(result.confidence).to eq(1.0)
    end

    it 'detects UTF-16 LE BOM with confidence 1.0' do
      bom_string = "\xFF\xFEh\x00i\x00".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_16LE)
      expect(result.confidence).to eq(1.0)
    end

    it 'detects UTF-16 BE BOM with confidence 1.0' do
      bom_string = "\xFE\xFF\x00h\x00i".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_16BE)
      expect(result.confidence).to eq(1.0)
    end

    it 'detects UTF-32 BE BOM with confidence 1.0' do
      bom_string = "\x00\x00\xFE\xFFtest".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_32BE)
      expect(result.confidence).to eq(1.0)
    end

    it 'detects UTF-32 LE BOM with confidence 1.0' do
      bom_string = "\xFF\xFE\x00\x00test".b
      result = described_class.detect(bom_string)
      expect(result).to eq(Encoding::UTF_32LE)
      expect(result.confidence).to eq(1.0)
    end

    it 'detects Latin-1 for high-byte content that is not valid UTF-8' do
      latin1_string = "caf\xE9".b
      result = described_class.detect(latin1_string)
      expect(result).to eq(Encoding::ISO_8859_1)
      expect(result.confidence).to eq(0.7)
    end

    it 'falls back for pure ASCII-range control chars' do
      binary = "\x01\x02\x03\x04\x05\x06\x07\x08".b
      result = described_class.detect(binary)
      expect(result.confidence).to be <= 1.0
      expect(result.confidence).to be > 0.0
    end

    context 'DetectionResult backward compatibility' do
      it 'can be compared with == to an Encoding' do
        result = described_class.detect("caf\xC3\xA9".b)
        expect(result == Encoding::UTF_8).to be true
      end

      it 'delegates name to the encoding' do
        result = described_class.detect("caf\xC3\xA9".b)
        expect(result.name).to eq('UTF-8')
      end

      it 'delegates to_s to the encoding' do
        result = described_class.detect('hello'.b)
        expect(result.to_s).to eq('US-ASCII')
      end

      it 'supports to_h for hash representation' do
        result = described_class.detect("caf\xC3\xA9".b)
        hash = result.to_h
        expect(hash[:encoding]).to eq(Encoding::UTF_8)
        expect(hash[:confidence]).to be_a(Float)
      end

      it 'supports eql? and hash for use as hash keys' do
        r1 = described_class.detect("caf\xC3\xA9".b)
        r2 = described_class.detect("\xEF\xBB\xBFhello".b)
        expect(r1.eql?(r2)).to be true # both UTF-8
        expect(r1.hash).to eq(r2.hash)
      end

      it 'responds to encoding methods' do
        result = described_class.detect("caf\xC3\xA9".b)
        expect(result.respond_to?(:name)).to be true
        expect(result.respond_to?(:nonexistent_method)).to be false
      end
    end
  end

  describe '.detect_stream' do
    it 'detects encoding from a StringIO' do
      io = StringIO.new("caf\xC3\xA9".b)
      result = described_class.detect_stream(io)
      expect(result).to eq(Encoding::UTF_8)
      expect(result).to be_a(Philiprehberger::EncodingKit::DetectionResult)
    end

    it 'detects encoding from a StringIO with BOM' do
      io = StringIO.new("\xEF\xBB\xBFhello world".b)
      result = described_class.detect_stream(io)
      expect(result).to eq(Encoding::UTF_8)
      expect(result.confidence).to eq(1.0)
    end

    it 'restores IO position after reading' do
      io = StringIO.new("caf\xC3\xA9 is coffee".b)
      io.pos = 0
      described_class.detect_stream(io)
      expect(io.pos).to eq(0)
    end

    it 'respects sample_size parameter' do
      # Create a large string with UTF-8 content
      content = ("caf\xC3\xA9 " * 1000).b
      io = StringIO.new(content)
      result = described_class.detect_stream(io, sample_size: 16)
      # Small sample may detect as UTF-8 or Latin-1 depending on byte boundaries
      expect(result.confidence).to be > 0.0
    end

    it 'handles empty IO' do
      io = StringIO.new(''.b)
      result = described_class.detect_stream(io)
      expect(result).to eq(Encoding::BINARY)
      expect(result.confidence).to eq(0.5)
    end

    it 'detects Latin-1 from a stream' do
      io = StringIO.new("caf\xE9".b)
      result = described_class.detect_stream(io)
      expect(result).to eq(Encoding::ISO_8859_1)
    end
  end

  describe '.analyze' do
    it 'returns a hash with required keys' do
      result = described_class.analyze('hello world')
      expect(result).to include(:encoding, :confidence, :printable_ratio, :ascii_ratio, :high_bytes, :candidates)
    end

    it 'reports correct stats for ASCII text' do
      result = described_class.analyze('hello')
      expect(result[:encoding]).to eq(Encoding::US_ASCII)
      expect(result[:printable_ratio]).to eq(1.0)
      expect(result[:ascii_ratio]).to eq(1.0)
      expect(result[:high_bytes]).to eq(0)
    end

    it 'reports correct stats for UTF-8 text with multibyte' do
      result = described_class.analyze("caf\xC3\xA9".b)
      expect(result[:encoding]).to eq(Encoding::UTF_8)
      expect(result[:ascii_ratio]).to be < 1.0
      expect(result[:high_bytes]).to eq(2)
    end

    it 'includes candidates sorted by confidence' do
      result = described_class.analyze("caf\xC3\xA9".b)
      candidates = result[:candidates]
      expect(candidates).to be_an(Array)
      expect(candidates.length).to be >= 1
      confidences = candidates.map { |c| c[:confidence] }
      expect(confidences).to eq(confidences.sort.reverse)
    end

    it 'includes multiple candidates for ambiguous content' do
      # Use bytes that are valid in multiple encodings
      result = described_class.analyze("caf\xE9 na\xEFve".b)
      candidates = result[:candidates]
      expect(candidates.length).to be >= 1
      encodings = candidates.map { |c| c[:encoding] }
      expect(encodings).to include(result[:encoding])
    end

    it 'handles empty strings' do
      result = described_class.analyze('')
      expect(result[:encoding]).to eq(Encoding::BINARY)
      expect(result[:printable_ratio]).to eq(0.0)
      expect(result[:ascii_ratio]).to eq(0.0)
      expect(result[:high_bytes]).to eq(0)
    end

    it 'reports printable_ratio correctly for mixed content' do
      # Mix of printable and non-printable bytes
      result = described_class.analyze("hello\x01\x02".b)
      expect(result[:printable_ratio]).to be < 1.0
      expect(result[:printable_ratio]).to be > 0.0
    end
  end

  describe 'Windows codepage detection' do
    it 'detects CP1252 by bytes in 0x80-0x9F range' do
      # CP1252 smart quotes: 0x93 (left double quote), 0x94 (right double quote)
      cp1252 = "Hello \x93world\x94".b
      result = described_class.detect(cp1252)
      expect(result).to eq(Encoding::Windows_1252)
      expect(result.confidence).to be_between(0.6, 0.7)
    end

    it 'detects CP1252 with higher confidence for many specific bytes' do
      # Multiple CP1252-specific bytes: euro sign (0x80), smart quotes, em dash (0x97)
      cp1252 = "Price: \x80 100 \x93quoted\x94 text \x96 more \x97 stuff".b
      result = described_class.detect(cp1252)
      expect(result).to eq(Encoding::Windows_1252)
      expect(result.confidence).to eq(0.7)
    end

    it 'detects CP1250 with Central European marker bytes' do
      # CP1250 markers: 0x8A (S-caron), 0x8E (Z-caron), 0x9A (s-caron), 0x9E (z-caron)
      cp1250 = "Czech: \x8A\x8E\x9A\x9E text".b
      result = described_class.detect(cp1250)
      expect(result).to eq(Encoding::Windows_1250)
      expect(result.confidence).to eq(0.6)
    end

    it 'detects CP1251 for Cyrillic content' do
      # CP1251 Cyrillic: bytes 0xC0-0xFF map to А-я
      # Build a string with mostly Cyrillic bytes and some 0x80-0x9F bytes
      cyrillic = "\xCF\xF0\xE8\xE2\xE5\xF2 \xEC\xE8\xF0 \x85".b
      result = described_class.detect(cyrillic)
      expect(result).to eq(Encoding::Windows_1251)
      expect(result.confidence).to eq(0.65)
    end
  end

  describe '.transcode' do
    it 'auto-detects source and transcodes to UTF-8 by default' do
      latin1 = "caf\xE9".b
      result = described_class.transcode(latin1)
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
    end

    it 'transcodes to a specified target encoding' do
      utf8 = "caf\u00E9"
      result = described_class.transcode(utf8, to: Encoding::ISO_8859_1)
      expect(result.encoding).to eq(Encoding::ISO_8859_1)
      expect(result.bytes.to_a).to include(0xE9)
    end

    it 'accepts encoding name as string' do
      utf8 = "caf\u00E9"
      result = described_class.transcode(utf8, to: 'ISO-8859-1')
      expect(result.encoding).to eq(Encoding::ISO_8859_1)
    end

    it 'replaces invalid bytes by default' do
      bad = "\xFF\xFE mixed \xC3\xA9".b
      result = described_class.transcode(bad, to: Encoding::UTF_8)
      expect(result.encoding).to eq(Encoding::UTF_8)
      expect(result.valid_encoding?).to be true
    end

    it 'uses custom replacement character' do
      bad = "\xFF\xFE mixed".b
      result = described_class.transcode(bad, to: Encoding::US_ASCII, replace: '*')
      expect(result.encoding).to eq(Encoding::US_ASCII)
      expect(result).to include('*')
    end

    it 'raises on failure when fallback is :raise' do
      # CP1252 specific byte that cannot be represented in US-ASCII
      cp1252 = "\x93hello\x94".b
      expect do
        described_class.transcode(cp1252, to: Encoding::US_ASCII, fallback: :raise)
      end.to raise_error(Philiprehberger::EncodingKit::Error)
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

  describe '.detect_file' do
    it 'detects UTF-8 encoding from a file' do
      Tempfile.create(['encoding_test', '.txt']) do |f|
        f.binmode
        f.write("caf\xC3\xA9")
        f.flush
        result = described_class.detect_file(f.path)
        expect(result).to eq(Encoding::UTF_8)
        expect(result.confidence).to be_between(0.8, 0.9)
      end
    end

    it 'detects BOM with confidence 1.0' do
      Tempfile.create(['bom_test', '.txt']) do |f|
        f.binmode
        f.write("\xEF\xBB\xBFhello world")
        f.flush
        result = described_class.detect_file(f.path)
        expect(result).to eq(Encoding::UTF_8)
        expect(result.confidence).to eq(1.0)
      end
    end

    it 'respects sample_size parameter' do
      Tempfile.create(['sample_test', '.txt']) do |f|
        f.binmode
        f.write("caf\xC3\xA9 " * 1000)
        f.flush
        result = described_class.detect_file(f.path, sample_size: 16)
        expect(result.confidence).to be > 0.0
      end
    end

    it 'raises Errno::ENOENT for missing files' do
      expect { described_class.detect_file('/tmp/nonexistent_file_xyz.txt') }.to raise_error(Errno::ENOENT)
    end

    it 'handles empty files' do
      Tempfile.create(['empty_test', '.txt']) do |f|
        f.flush
        result = described_class.detect_file(f.path)
        expect(result).to eq(Encoding::BINARY)
        expect(result.confidence).to eq(0.5)
      end
    end
  end

  describe '.read_as_utf8' do
    it 'reads a UTF-8 file and returns UTF-8 string' do
      Tempfile.create(['read_test', '.txt']) do |f|
        f.binmode
        f.write("caf\xC3\xA9")
        f.flush
        result = described_class.read_as_utf8(f.path)
        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result.valid_encoding?).to be true
      end
    end

    it 'reads a Latin-1 file with auto-detection' do
      Tempfile.create(['latin1_test', '.txt']) do |f|
        f.binmode
        f.write("caf\xE9")
        f.flush
        result = described_class.read_as_utf8(f.path)
        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result.valid_encoding?).to be true
      end
    end

    it 'reads with explicit from: encoding' do
      Tempfile.create(['explicit_test', '.txt']) do |f|
        f.binmode
        f.write("caf\xE9")
        f.flush
        result = described_class.read_as_utf8(f.path, from: Encoding::ISO_8859_1)
        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result).to include("\u00E9")
      end
    end

    it 'replaces invalid bytes with replacement character' do
      Tempfile.create(['invalid_test', '.txt']) do |f|
        f.binmode
        f.write("\xFF\xFE")
        f.flush
        result = described_class.read_as_utf8(f.path, from: Encoding::UTF_8)
        expect(result.encoding).to eq(Encoding::UTF_8)
        expect(result.valid_encoding?).to be true
      end
    end
  end

  describe '.file_valid?' do
    it 'returns true for a valid UTF-8 file' do
      Tempfile.create(['valid_test', '.txt']) do |f|
        f.binmode
        f.write("caf\xC3\xA9")
        f.flush
        expect(described_class.file_valid?(f.path, encoding: Encoding::UTF_8)).to be true
      end
    end

    it 'returns false for invalid bytes in specified encoding' do
      Tempfile.create(['invalid_test', '.txt']) do |f|
        f.binmode
        f.write("\xFF\xFE")
        f.flush
        expect(described_class.file_valid?(f.path, encoding: Encoding::UTF_8)).to be false
      end
    end

    it 'checks against binary encoding when no encoding specified' do
      Tempfile.create(['binary_test', '.txt']) do |f|
        f.binmode
        f.write("\x00\x01\x02")
        f.flush
        expect(described_class.file_valid?(f.path)).to be true
      end
    end
  end

  describe '.guess_from_filename' do
    it 'returns UTF-8 for .utf8 extension' do
      expect(described_class.guess_from_filename('data.utf8.csv')).to eq(Encoding::UTF_8)
    end

    it 'returns Latin-1 for .latin1 hint' do
      expect(described_class.guess_from_filename('legacy.latin1.txt')).to eq(Encoding::ISO_8859_1)
    end

    it 'recognises UTF-16 hint' do
      expect(described_class.guess_from_filename('snapshot.UTF-16.xml')).to eq(Encoding::UTF_16)
    end

    it 'recognises windows-1252' do
      expect(described_class.guess_from_filename('file.cp1252.csv')).to eq(Encoding::Windows_1252)
    end

    it 'strips path components before matching' do
      expect(described_class.guess_from_filename('/srv/data/archive.utf-8.log')).to eq(Encoding::UTF_8)
    end

    it 'returns nil when no hint is present' do
      expect(described_class.guess_from_filename('report.csv')).to be_nil
    end

    it 'returns nil for empty string' do
      expect(described_class.guess_from_filename('')).to be_nil
    end
  end
end

RSpec.describe Philiprehberger::EncodingKit::DetectionResult do
  subject(:result) { described_class.new(Encoding::UTF_8, 0.9) }

  describe '#encoding' do
    it 'returns the encoding' do
      expect(result.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe '#confidence' do
    it 'returns the confidence score' do
      expect(result.confidence).to eq(0.9)
    end

    it 'converts to float' do
      r = described_class.new(Encoding::UTF_8, 1)
      expect(r.confidence).to be_a(Float)
    end
  end

  describe '#==' do
    it 'equals the same encoding' do
      expect(result == Encoding::UTF_8).to be true
    end

    it 'does not equal a different encoding' do
      expect(result == Encoding::ISO_8859_1).to be false
    end

    it 'equals another DetectionResult with same encoding' do
      other = described_class.new(Encoding::UTF_8, 0.5)
      expect(result == other).to be true
    end

    it 'does not equal another DetectionResult with different encoding' do
      other = described_class.new(Encoding::ISO_8859_1, 0.9)
      expect(result == other).to be false
    end
  end

  describe '#to_s' do
    it 'returns the encoding name' do
      expect(result.to_s).to eq('UTF-8')
    end
  end

  describe '#inspect' do
    it 'includes encoding and confidence' do
      expect(result.inspect).to include('UTF-8')
      expect(result.inspect).to include('0.9')
    end
  end

  describe '#to_h' do
    it 'returns a hash with encoding and confidence' do
      expect(result.to_h).to eq({ encoding: Encoding::UTF_8, confidence: 0.9 })
    end
  end

  describe 'method delegation' do
    it 'delegates name to encoding' do
      expect(result.name).to eq('UTF-8')
    end

    it 'delegates respond_to_missing? correctly' do
      expect(result.respond_to?(:name)).to be true
      expect(result.respond_to?(:totally_fake_method)).to be false
    end
  end
end
