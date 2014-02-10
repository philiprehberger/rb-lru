# frozen_string_literal: true

require_relative 'lib/philiprehberger/lru/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-lru'
  spec.version       = Philiprehberger::Lru::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Thread-safe LRU cache with TTL, eviction callbacks, and hit/miss statistics'
  spec.description   = 'Thread-safe LRU cache backed by a hash and doubly-linked list for O(1) get/set, ' \
                       'with configurable TTL expiration, eviction callbacks, and hit/miss statistics.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-lru'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
