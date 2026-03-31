# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-28

### Added

- Confidence scores: `detect` returns a `DetectionResult` with `.encoding` and `.confidence` (1.0 for BOM, 0.5-0.9 for heuristics)
- `DetectionResult` delegates to `Encoding` for backward compatibility (e.g., `result == Encoding::UTF_8` still works)
- Streaming detection: `detect_stream(io, sample_size: 4096)` reads a sample from IO objects
- Encoding analysis: `analyze(string)` returns byte distribution stats and ranked candidates
- Windows codepage support: CP1252, CP1250, CP1251 detection via 0x80-0x9F byte patterns
- Transcode alias: `transcode(string, to:, fallback:, replace:)` for simplified auto-detect-and-convert
- Issue templates for bug reports and feature requests
- Dependabot configuration for bundler and GitHub Actions
- Pull request template

## [0.1.1] - 2026-03-26

### Added

- Add GitHub funding configuration

## [0.1.0] - 2026-03-26

### Added
- Initial release
- Encoding detection via BOM inspection and byte-pattern heuristics
- Conversion between encodings with fallback options
- UTF-8 normalization with replacement character support
- BOM detection and stripping
- Encoding validity checks
