# frozen_string_literal: true

require_relative 'lru/version'

module Philiprehberger
  module Lru
    class Error < StandardError; end

    # Node for the doubly-linked list
    #
    # @api private
    class Node
      attr_accessor :key, :value, :expires_at, :prev_node, :next_node

      def initialize(key, value, expires_at: nil)
        @key = key
        @value = value
        @expires_at = expires_at
        @prev_node = nil
        @next_node = nil
      end

      def expired?
        return false if @expires_at.nil?

        Time.now >= @expires_at
      end
    end

    # Thread-safe LRU cache with TTL, eviction callbacks, and hit/miss statistics
    #
    # @example
    #   cache = Philiprehberger::Lru::Cache.new(max_size: 100, ttl: 300)
    #   cache.set(:user, { name: 'Alice' })
    #   cache.get(:user) # => { name: 'Alice' }
    class Cache
      # Create a new LRU cache
      #
      # @param max_size [Integer] maximum number of entries
      # @param ttl [Numeric, nil] time-to-live in seconds (nil for no expiration)
      # @return [Cache]
      def initialize(max_size:, ttl: nil)
        raise Error, 'max_size must be a positive integer' unless max_size.is_a?(Integer) && max_size.positive?
        raise Error, 'ttl must be a positive number' if ttl && (!ttl.is_a?(Numeric) || ttl <= 0)

        @max_size = max_size
        @ttl = ttl
        @map = {}
        @head = nil
        @tail = nil
        @mutex = Mutex.new
        @on_evict = nil
        @hits = 0
        @misses = 0
        @evictions = 0
      end

      # Store a key-value pair in the cache
      #
      # @param key [Object] the cache key
      # @param value [Object] the value to store
      # @return [Object] the stored value
      def set(key, value)
        @mutex.synchronize do
          if @map.key?(key)
            node = @map[key]
            node.value = value
            node.expires_at = @ttl ? Time.now + @ttl : nil
            move_to_front(node)
          else
            evict_one while @map.size >= @max_size
            expires_at = @ttl ? Time.now + @ttl : nil
            node = Node.new(key, value, expires_at: expires_at)
            @map[key] = node
            prepend_node(node)
          end
          value
        end
      end

      # Retrieve a value by key
      #
      # @param key [Object] the cache key
      # @return [Object, nil] the cached value or nil if not found/expired
      def get(key)
        @mutex.synchronize do
          node = @map[key]
          if node.nil?
            @misses += 1
            return nil
          end

          if node.expired?
            remove_node(node)
            @map.delete(key)
            @evictions += 1
            notify_evict(key, node.value)
            @misses += 1
            return nil
          end

          move_to_front(node)
          @hits += 1
          node.value
        end
      end

      # Retrieve a value by key, or compute and store it using the block
      #
      # @param key [Object] the cache key
      # @yield computes the value if the key is not found
      # @return [Object] the cached or computed value
      def fetch(key, &block)
        @mutex.synchronize do
          node = @map[key]

          if node && !node.expired?
            move_to_front(node)
            @hits += 1
            return node.value
          end

          if node&.expired?
            remove_node(node)
            @map.delete(key)
            @evictions += 1
            notify_evict(key, node.value)
          end

          @misses += 1
        end

        return nil unless block

        value = yield
        set(key, value)
        value
      end

      # Delete a key from the cache
      #
      # @param key [Object] the cache key
      # @return [Object, nil] the removed value or nil
      def delete(key)
        @mutex.synchronize do
          node = @map.delete(key)
          return nil unless node

          remove_node(node)
          node.value
        end
      end

      # Remove all entries from the cache
      #
      # @return [void]
      def clear
        @mutex.synchronize do
          @map.clear
          @head = nil
          @tail = nil
        end
      end

      # Register an eviction callback
      #
      # @yield [key, value] called when an entry is evicted
      # @return [void]
      def on_evict(&block)
        @mutex.synchronize do
          @on_evict = block
        end
      end

      # Bulk insert from a hash
      #
      # @param hash [Hash] key-value pairs to store
      # @return [void]
      def set_many(hash)
        hash.each { |k, v| set(k, v) }
        nil
      end

      # Retrieve multiple values by key
      #
      # @param keys [Array<Object>] the cache keys
      # @return [Hash] key => value for each key (nil for misses)
      def get_many(*keys)
        keys.flatten.to_h { |k| [k, get(k)] }
      end

      # Bulk delete keys from the cache
      #
      # @param keys [Array<Object>] the cache keys to delete
      # @return [Integer] number of keys actually deleted
      def delete_many(*keys)
        keys.flatten.count { |k| !delete(k).nil? }
      end

      # Return the hit rate as a float between 0.0 and 1.0
      #
      # @return [Float]
      def hit_rate
        @mutex.synchronize do
          total = @hits + @misses
          return 0.0 if total.zero?

          @hits.to_f / total
        end
      end

      # Return the miss rate as a float between 0.0 and 1.0
      #
      # @return [Float]
      def miss_rate
        @mutex.synchronize do
          total = @hits + @misses
          return 0.0 if total.zero?

          @misses.to_f / total
        end
      end

      # Reset hit, miss, and eviction counters to zero
      #
      # @return [void]
      def reset_stats
        @mutex.synchronize do
          @hits = 0
          @misses = 0
          @evictions = 0
        end
      end

      # Return cache statistics
      #
      # @return [Hash] hits, misses, evictions, and current size
      def stats
        @mutex.synchronize do
          { hits: @hits, misses: @misses, evictions: @evictions, size: @map.size }
        end
      end

      # Return the current number of entries
      #
      # @return [Integer]
      def size
        @mutex.synchronize { @map.size }
      end

      # Return the configured maximum size
      #
      # @return [Integer]
      attr_reader :max_size

      # Return the configured TTL in seconds
      #
      # @return [Numeric, nil]
      attr_reader :ttl

      # Return all keys in the cache (most recently used first)
      #
      # @return [Array]
      def keys
        @mutex.synchronize do
          result = []
          node = @head
          while node
            result << node.key unless node.expired?
            node = node.next_node
          end
          result
        end
      end

      # Return all values in the cache (most recently used first)
      #
      # @return [Array]
      def values
        @mutex.synchronize do
          result = []
          node = @head
          while node
            result << node.value unless node.expired?
            node = node.next_node
          end
          result
        end
      end

      # Check whether a key exists in the cache and is not expired
      #
      # @param key [Object] the cache key
      # @return [Boolean]
      def include?(key)
        @mutex.synchronize do
          node = @map[key]
          return false if node.nil?
          return false if node.expired?

          true
        end
      end

      alias key? include?

      # Check whether the cache is empty
      #
      # @return [Boolean]
      def empty?
        @mutex.synchronize { @map.empty? }
      end

      private

      def prepend_node(node)
        node.prev_node = nil
        node.next_node = @head
        @head.prev_node = node if @head
        @head = node
        @tail = node if @tail.nil?
      end

      def remove_node(node)
        if node.prev_node
          node.prev_node.next_node = node.next_node
        else
          @head = node.next_node
        end

        if node.next_node
          node.next_node.prev_node = node.prev_node
        else
          @tail = node.prev_node
        end

        node.prev_node = nil
        node.next_node = nil
      end

      def move_to_front(node)
        return if node == @head

        remove_node(node)
        prepend_node(node)
      end

      def evict_one
        return unless @tail

        node = @tail
        remove_node(node)
        @map.delete(node.key)
        @evictions += 1
        notify_evict(node.key, node.value)
      end

      def notify_evict(key, value)
        @on_evict&.call(key, value)
      end
    end
  end
end
