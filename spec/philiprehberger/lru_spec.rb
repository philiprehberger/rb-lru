# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Lru do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end
end

RSpec.describe Philiprehberger::Lru::Cache do
  describe '#set and #get' do
    it 'stores and retrieves a value' do
      cache = described_class.new(max_size: 10)
      cache.set(:key, 'value')
      expect(cache.get(:key)).to eq('value')
    end

    it 'returns nil for missing keys' do
      cache = described_class.new(max_size: 10)
      expect(cache.get(:missing)).to be_nil
    end

    it 'overwrites existing keys' do
      cache = described_class.new(max_size: 10)
      cache.set(:key, 'old')
      cache.set(:key, 'new')
      expect(cache.get(:key)).to eq('new')
    end

    it 'evicts the least recently used entry when full' do
      cache = described_class.new(max_size: 2)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      expect(cache.get(:a)).to be_nil
      expect(cache.get(:b)).to eq(2)
      expect(cache.get(:c)).to eq(3)
    end

    it 'promotes accessed entries to most recently used' do
      cache = described_class.new(max_size: 2)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.get(:a)
      cache.set(:c, 3)
      expect(cache.get(:a)).to eq(1)
      expect(cache.get(:b)).to be_nil
    end
  end

  describe 'TTL expiration' do
    it 'expires entries after TTL' do
      cache = described_class.new(max_size: 10, ttl: 0.01)
      cache.set(:key, 'value')
      sleep(0.02)
      expect(cache.get(:key)).to be_nil
    end

    it 'returns value before TTL expires' do
      cache = described_class.new(max_size: 10, ttl: 10)
      cache.set(:key, 'value')
      expect(cache.get(:key)).to eq('value')
    end
  end

  describe '#fetch' do
    it 'returns cached value when present' do
      cache = described_class.new(max_size: 10)
      cache.set(:key, 'cached')
      result = cache.fetch(:key) { 'computed' }
      expect(result).to eq('cached')
    end

    it 'computes and stores value when missing' do
      cache = described_class.new(max_size: 10)
      result = cache.fetch(:key) { 'computed' }
      expect(result).to eq('computed')
      expect(cache.get(:key)).to eq('computed')
    end

    it 'returns nil when missing and no block given' do
      cache = described_class.new(max_size: 10)
      expect(cache.fetch(:key)).to be_nil
    end

    it 'recomputes when TTL expired' do
      cache = described_class.new(max_size: 10, ttl: 0.01)
      cache.set(:key, 'old')
      sleep(0.02)
      result = cache.fetch(:key) { 'new' }
      expect(result).to eq('new')
    end
  end

  describe '#delete' do
    it 'removes an entry' do
      cache = described_class.new(max_size: 10)
      cache.set(:key, 'value')
      expect(cache.delete(:key)).to eq('value')
      expect(cache.get(:key)).to be_nil
    end

    it 'returns nil for missing keys' do
      cache = described_class.new(max_size: 10)
      expect(cache.delete(:missing)).to be_nil
    end
  end

  describe '#clear' do
    it 'removes all entries' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.clear
      expect(cache.get(:a)).to be_nil
      expect(cache.get(:b)).to be_nil
      expect(cache.size).to eq(0)
    end
  end

  describe '#on_evict' do
    it 'calls the callback when an entry is evicted' do
      evicted = []
      cache = described_class.new(max_size: 2)
      cache.on_evict { |k, v| evicted << [k, v] }
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      expect(evicted).to eq([[:a, 1]])
    end
  end

  describe '#stats' do
    it 'tracks hits, misses, evictions, and size' do
      cache = described_class.new(max_size: 2)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.get(:a)
      cache.get(:missing)
      cache.set(:c, 3)
      stats = cache.stats
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
      expect(stats[:evictions]).to eq(1)
      expect(stats[:size]).to eq(2)
    end
  end

  describe 'validation' do
    it 'raises for non-positive max_size' do
      expect { described_class.new(max_size: 0) }.to raise_error(Philiprehberger::Lru::Error)
    end

    it 'raises for negative max_size' do
      expect { described_class.new(max_size: -5) }.to raise_error(Philiprehberger::Lru::Error)
    end

    it 'raises for non-positive ttl' do
      expect { described_class.new(max_size: 10, ttl: -1) }.to raise_error(Philiprehberger::Lru::Error)
    end

    it 'raises for zero ttl' do
      expect { described_class.new(max_size: 10, ttl: 0) }.to raise_error(Philiprehberger::Lru::Error)
    end

    it 'raises for non-integer max_size' do
      expect { described_class.new(max_size: 'abc') }.to raise_error(Philiprehberger::Lru::Error)
    end
  end

  describe 'access order updates recency' do
    it 'get promotes entry so it is not evicted' do
      cache = described_class.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      cache.get(:a) # promote :a
      cache.set(:d, 4) # should evict :b (least recent)

      expect(cache.get(:a)).to eq(1)
      expect(cache.get(:b)).to be_nil
      expect(cache.get(:c)).to eq(3)
      expect(cache.get(:d)).to eq(4)
    end

    it 'set on existing key promotes entry' do
      cache = described_class.new(max_size: 2)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:a, 10) # update and promote :a
      cache.set(:c, 3) # should evict :b

      expect(cache.get(:a)).to eq(10)
      expect(cache.get(:b)).to be_nil
      expect(cache.get(:c)).to eq(3)
    end
  end

  describe 'eviction order' do
    it 'evicts in LRU order when adding beyond capacity' do
      cache = described_class.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      cache.set(:d, 4) # evicts :a
      cache.set(:e, 5) # evicts :b

      expect(cache.get(:a)).to be_nil
      expect(cache.get(:b)).to be_nil
      expect(cache.get(:c)).to eq(3)
    end

    it 'evicts correctly with max_size of 1' do
      cache = described_class.new(max_size: 1)
      cache.set(:a, 1)
      cache.set(:b, 2)

      expect(cache.get(:a)).to be_nil
      expect(cache.get(:b)).to eq(2)
      expect(cache.size).to eq(1)
    end
  end

  describe '#delete specific key' do
    it 'removes only the specified key' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      cache.delete(:b)

      expect(cache.get(:a)).to eq(1)
      expect(cache.get(:b)).to be_nil
      expect(cache.get(:c)).to eq(3)
      expect(cache.size).to eq(2)
    end

    it 'allows reinsertion after delete' do
      cache = described_class.new(max_size: 10)
      cache.set(:key, 'old')
      cache.delete(:key)
      cache.set(:key, 'new')
      expect(cache.get(:key)).to eq('new')
    end
  end

  describe '#clear resets everything' do
    it 'resets size to zero' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.clear
      expect(cache.size).to eq(0)
    end

    it 'allows reuse after clear' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.clear
      cache.set(:b, 2)
      expect(cache.get(:a)).to be_nil
      expect(cache.get(:b)).to eq(2)
    end
  end

  describe '#on_evict callback details' do
    it 'fires callback for TTL-expired entries on get' do
      evicted = []
      cache = described_class.new(max_size: 10, ttl: 0.01)
      cache.on_evict { |k, v| evicted << [k, v] }
      cache.set(:key, 'value')
      sleep(0.02)
      cache.get(:key)
      expect(evicted).to eq([[:key, 'value']])
    end

    it 'fires callback for each evicted entry in order' do
      evicted = []
      cache = described_class.new(max_size: 2)
      cache.on_evict { |k, v| evicted << [k, v] }
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3) # evicts :a
      cache.set(:d, 4) # evicts :b
      expect(evicted).to eq([[:a, 1], [:b, 2]])
    end
  end

  describe '#fetch edge cases' do
    it 'does not call block when key exists' do
      cache = described_class.new(max_size: 10)
      cache.set(:key, 'cached')
      block_called = false
      cache.fetch(:key) do
        block_called = true
        'new'
      end
      expect(block_called).to be false
    end

    it 'caches the computed value from the block' do
      cache = described_class.new(max_size: 10)
      cache.fetch(:key) { 'computed' }
      expect(cache.get(:key)).to eq('computed')
    end
  end

  describe '#stats detailed tracking' do
    it 'tracks hits correctly across multiple gets' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      3.times { cache.get(:a) }
      expect(cache.stats[:hits]).to eq(3)
    end

    it 'tracks misses for non-existent keys' do
      cache = described_class.new(max_size: 10)
      cache.get(:missing1)
      cache.get(:missing2)
      expect(cache.stats[:misses]).to eq(2)
    end

    it 'tracks evictions from TTL expiry' do
      cache = described_class.new(max_size: 10, ttl: 0.01)
      cache.set(:key, 'val')
      sleep(0.02)
      cache.get(:key) # triggers TTL eviction
      expect(cache.stats[:evictions]).to eq(1)
    end
  end

  describe '#set_many' do
    it 'inserts all key-value pairs from a hash' do
      cache = described_class.new(max_size: 10)
      cache.set_many(a: 1, b: 2, c: 3)
      expect(cache.get(:a)).to eq(1)
      expect(cache.get(:b)).to eq(2)
      expect(cache.get(:c)).to eq(3)
      expect(cache.size).to eq(3)
    end

    it 'triggers LRU eviction when exceeding max_size' do
      cache = described_class.new(max_size: 2)
      cache.set_many(a: 1, b: 2, c: 3)
      expect(cache.get(:a)).to be_nil
      expect(cache.size).to eq(2)
    end

    it 'overwrites existing keys' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 'old')
      cache.set_many(a: 'new', b: 2)
      expect(cache.get(:a)).to eq('new')
    end

    it 'handles an empty hash' do
      cache = described_class.new(max_size: 10)
      cache.set_many({})
      expect(cache.size).to eq(0)
    end
  end

  describe '#get_many' do
    it 'returns a hash of found values' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.set(:b, 2)
      result = cache.get_many(:a, :b)
      expect(result).to eq(a: 1, b: 2)
    end

    it 'returns nil for missing keys' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      result = cache.get_many(:a, :missing)
      expect(result).to eq(a: 1, missing: nil)
    end

    it 'tracks hits and misses correctly' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.get_many(:a, :missing)
      expect(cache.stats[:hits]).to eq(1)
      expect(cache.stats[:misses]).to eq(1)
    end

    it 'handles empty arguments' do
      cache = described_class.new(max_size: 10)
      expect(cache.get_many).to eq({})
    end
  end

  describe '#delete_many' do
    it 'deletes multiple existing keys and returns count' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      expect(cache.delete_many(:a, :c)).to eq(2)
      expect(cache.size).to eq(1)
      expect(cache.get(:b)).to eq(2)
    end

    it 'returns 0 for non-existing keys' do
      cache = described_class.new(max_size: 10)
      expect(cache.delete_many(:x, :y)).to eq(0)
    end

    it 'counts only actually deleted keys in mixed case' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      expect(cache.delete_many(:a, :missing)).to eq(1)
    end

    it 'handles empty arguments' do
      cache = described_class.new(max_size: 10)
      expect(cache.delete_many).to eq(0)
    end
  end

  describe '#hit_rate' do
    it 'returns the fraction of hits over total accesses' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.get(:a)       # hit
      cache.get(:a)       # hit
      cache.get(:missing) # miss
      expect(cache.hit_rate).to be_within(0.001).of(2.0 / 3)
    end

    it 'returns 0.0 when there are no accesses' do
      cache = described_class.new(max_size: 10)
      expect(cache.hit_rate).to eq(0.0)
    end
  end

  describe '#miss_rate' do
    it 'returns the fraction of misses over total accesses' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.get(:a)       # hit
      cache.get(:missing) # miss
      cache.get(:nope)    # miss
      expect(cache.miss_rate).to be_within(0.001).of(2.0 / 3)
    end

    it 'returns 0.0 when there are no accesses' do
      cache = described_class.new(max_size: 10)
      expect(cache.miss_rate).to eq(0.0)
    end
  end

  describe '#reset_stats' do
    it 'clears hit, miss, and eviction counters' do
      cache = described_class.new(max_size: 2)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3) # evicts :a
      cache.get(:b)     # hit
      cache.get(:z)     # miss
      cache.reset_stats
      expect(cache.stats).to eq(hits: 0, misses: 0, evictions: 0, size: 2)
    end

    it 'does not clear cached data' do
      cache = described_class.new(max_size: 10)
      cache.set(:a, 1)
      cache.get(:a)
      cache.reset_stats
      expect(cache.get(:a)).to eq(1)
    end
  end

  describe '#size' do
    it 'reflects current entry count' do
      cache = described_class.new(max_size: 10)
      expect(cache.size).to eq(0)
      cache.set(:a, 1)
      expect(cache.size).to eq(1)
      cache.set(:b, 2)
      expect(cache.size).to eq(2)
      cache.delete(:a)
      expect(cache.size).to eq(1)
    end
  end

  describe '#peek' do
    it 'returns the value without promoting the key' do
      cache = described_class.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)

      expect(cache.peek(:a)).to eq(1)
      # :a should still be least-recently-used; adding :d should evict :a
      cache.set(:d, 4)
      expect(cache.get(:a)).to be_nil
    end

    it 'returns nil for missing keys' do
      cache = described_class.new(max_size: 3)
      expect(cache.peek(:missing)).to be_nil
    end

    it 'returns nil for expired keys' do
      cache = described_class.new(max_size: 3, ttl: 0.05)
      cache.set(:x, 1)
      sleep 0.1
      expect(cache.peek(:x)).to be_nil
    end

    it 'does not affect hit/miss stats' do
      cache = described_class.new(max_size: 3)
      cache.set(:a, 1)
      cache.peek(:a)
      cache.peek(:missing)
      expect(cache.stats[:hits]).to eq(0)
      expect(cache.stats[:misses]).to eq(0)
    end
  end

  describe '#resize' do
    it 'shrinks the cache and evicts LRU entries' do
      cache = described_class.new(max_size: 5)
      (1..5).each { |i| cache.set(i, i) }
      cache.resize(3)
      expect(cache.size).to eq(3)
      expect(cache.max_size).to eq(3)
      # LRU entries 1 and 2 should have been evicted
      expect(cache.get(1)).to be_nil
      expect(cache.get(2)).to be_nil
      expect(cache.get(3)).to eq(3)
    end

    it 'grows the cache allowing more entries' do
      cache = described_class.new(max_size: 2)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.resize(4)
      cache.set(:c, 3)
      cache.set(:d, 4)
      expect(cache.size).to eq(4)
    end

    it 'triggers eviction callbacks on resize' do
      evicted = []
      cache = described_class.new(max_size: 3)
      cache.on_evict { |k, v| evicted << [k, v] }
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      cache.resize(1)
      expect(evicted.size).to eq(2)
    end

    it 'raises on invalid new_max' do
      cache = described_class.new(max_size: 3)
      expect { cache.resize(0) }.to raise_error(Philiprehberger::Lru::Error)
      expect { cache.resize(-1) }.to raise_error(Philiprehberger::Lru::Error)
    end
  end

  describe '#each' do
    it 'yields entries in MRU order' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      pairs = cache.map { |k, v| [k, v] }
      expect(pairs).to eq([[:c, 3], [:b, 2], [:a, 1]])
    end

    it 'returns an Enumerator when no block is given' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 2)
      cache.set(:a, 1)
      cache.set(:b, 2)
      expect(cache.each).to be_a(Enumerator)
    end

    it 'integrates with Enumerable' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      expect(cache.map { |_, v| v }).to contain_exactly(1, 2)
    end

    it 'skips expired entries' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3, ttl: 0.05)
      cache.set(:a, 1)
      sleep 0.1
      cache.set(:b, 2)
      pairs = cache.each.to_a
      expect(pairs).to eq([[:b, 2]])
    end
  end

  describe '#oldest_key / #newest_key' do
    it 'returns nil for an empty cache' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3)
      expect(cache.oldest_key).to be_nil
      expect(cache.newest_key).to be_nil
    end

    it 'reports MRU/LRU after a sequence of sets' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)
      expect(cache.newest_key).to eq(:c)
      expect(cache.oldest_key).to eq(:a)
    end

    it 'updates LRU/MRU when get promotes a key' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.set(:c, 3)

      cache.get(:a)
      expect(cache.newest_key).to eq(:a)
      expect(cache.oldest_key).to eq(:b)
    end

    it 'does not promote LRU order when called' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3)
      cache.set(:a, 1)
      cache.set(:b, 2)
      cache.oldest_key
      cache.newest_key
      cache.set(:c, 3)
      cache.set(:d, 4) # evicts the LRU
      expect(cache.include?(:a)).to be false
    end

    it 'skips expired tail nodes' do
      cache = Philiprehberger::Lru::Cache.new(max_size: 3, ttl: 0.05)
      cache.set(:expired, 1)
      sleep 0.1
      cache.set(:fresh, 2)
      expect(cache.oldest_key).to eq(:fresh)
      expect(cache.newest_key).to eq(:fresh)
    end
  end
end
