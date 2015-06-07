# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
