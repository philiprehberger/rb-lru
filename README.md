# philiprehberger-lru

[![Tests](https://github.com/philiprehberger/rb-lru/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-lru/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-lru.svg)](https://rubygems.org/gems/philiprehberger-lru)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-lru)](https://github.com/philiprehberger/rb-lru/commits/main)

Thread-safe LRU cache with TTL, eviction callbacks, and hit/miss statistics

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-lru"
```

Or install directly:

```bash
gem install philiprehberger-lru
```

## Usage

```ruby
require "philiprehberger/lru"

cache = Philiprehberger::Lru::Cache.new(max_size: 100, ttl: 300)
cache.set(:user, { name: 'Alice' })
cache.get(:user) # => { name: 'Alice' }
```

### Fetch with Block

```ruby
cache.fetch(:config) { load_config_from_disk }
```

### Eviction Callbacks

```ruby
cache.on_evict { |key, value| logger.info("Evicted #{key}") }
```

### Statistics

```ruby
cache.stats # => { hits: 42, misses: 3, evictions: 1, size: 97 }
```

## API

| Method | Description |
|--------|-------------|
| `.new(max_size:, ttl:)` | Create a new LRU cache |
| `#set(key, value)` | Store a key-value pair |
| `#get(key)` | Retrieve a value by key |
| `#fetch(key) { block }` | Get or compute and store a value |
| `#delete(key)` | Remove a key from the cache |
| `#clear` | Remove all entries |
| `#on_evict { \|k, v\| }` | Register an eviction callback |
| `#stats` | Return hits, misses, evictions, and size |
| `#size` | Return the current number of entries |
| `#max_size` | Return the configured maximum size |
| `#ttl` | Return the configured TTL in seconds |
| `#keys` | Return all keys, most recently used first |
| `#values` | Return all values, most recently used first |
| `#include?(key)` | Check whether a key exists and is not expired |
| `#empty?` | Check whether the cache is empty |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-lru)

🐛 [Report issues](https://github.com/philiprehberger/rb-lru/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-lru/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
