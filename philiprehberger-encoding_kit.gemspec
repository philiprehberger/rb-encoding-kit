# frozen_string_literal: true

require_relative 'lib/philiprehberger/encoding_kit/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-encoding_kit'
  spec.version = Philiprehberger::EncodingKit::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']
  spec.summary = 'Character encoding detection, conversion, and normalization'
  spec.description = 'Detect encoding from BOM and heuristics with confidence scores, convert between encodings, ' \
                       'normalize to UTF-8, analyze byte distributions, and handle Windows codepages. Zero dependencies.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-encoding_kit'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-encoding-kit'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-encoding-kit/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-encoding-kit/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
