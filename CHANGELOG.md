# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-05-01

### Added
- `Cache#oldest_key` — key at the LRU end (the next entry to be evicted); does NOT promote LRU order
- `Cache#newest_key` — key at the MRU end (the most recently set or accessed entry); does NOT promote LRU order
- Both accessors skip expired tail/head nodes without removing them, making them safe for diagnostics and metrics

## [0.4.0] - 2026-04-15

### Added
- `Cache#each` — iterate non-expired entries in MRU order (Enumerable is now included)

## [0.3.0] - 2026-04-09

### Added
- `Cache#peek(key)` reads a value without promoting it in the LRU order or affecting statistics
- `Cache#resize(new_max)` changes capacity at runtime, evicting LRU entries if needed

## [0.2.0] - 2026-04-03

### Added
- Batch operations: `set_many`, `get_many`, `delete_many`
- Hit rate and miss rate convenience methods
- `reset_stats` to clear counters

## [0.1.4] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.1.3] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.1.2] - 2026-03-24

### Changed
- Expand README API table to document all public methods

## [0.1.1] - 2026-03-22

### Changed

- Expand test coverage to 30+ examples covering access order recency, LRU eviction order, delete/clear behavior, on_evict callback details, fetch edge cases, stats tracking, size tracking, and validation edge cases

## [0.1.0] - 2026-03-22

### Added

- Initial release
- Thread-safe LRU cache backed by hash and doubly-linked list
- O(1) get and set operations
- Configurable max size and TTL expiration
- Eviction callbacks via `on_evict`
- Hit/miss/eviction statistics via `stats`
- `fetch` with block for compute-on-miss pattern
