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
      cache.fetch(:key) { block_called = true; 'new' }
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
end
