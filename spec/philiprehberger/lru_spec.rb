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

    it 'raises for non-positive ttl' do
      expect { described_class.new(max_size: 10, ttl: -1) }.to raise_error(Philiprehberger::Lru::Error)
    end
  end
end
