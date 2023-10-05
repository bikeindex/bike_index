module Autocomplete
  BASE_KEY = "autc#{Rails.env.test? ? ":test" : ""}:".freeze
  SORTED_CATEGORY_ARRAY = %w[colors cycle_type frame_mnfg cmp_mnfg].freeze
  STOP_WORDS = [].freeze # I think we might want to include 'the'

  # The methods in this module should only be accessed by the subclasses.
  # I'm not sure how to do that correctly :/
  class << self
    def cache_duration
      600 # 10 minutes
    end

    def normalize(str)
      return "" if str.blank?
      I18n.transliterate(str.downcase).gsub(/[^\p{Word}\ ]/i, "")
        .strip.gsub(/\s+/, " ")
    end

    # TODO: is it better to have this be a method? Or just access the constant?
    def sorted_category_array
      SORTED_CATEGORY_ARRAY
    end

    def category_combos_key
      "#{BASE_KEY}category_combos:"
    end

    def category_combos
      redis { |r| r.smembers(category_combos_key) }
    end

    def category_key(name = "all")
      "#{BASE_KEY}cts:#{name}:"
    end

    def no_query_key(category = nil)
      "#{BASE_KEY}noq:#{category || category_key}"
    end

    def items_data_key
      "#{BASE_KEY}db:"
    end

    def cache_key(type = "all")
      "#{BASE_KEY}cache:#{type}:"
    end

    # Should be the canonical way of using Redis
    def redis
      # Basically, crib what is done in sidekiq
      raise ArgumentError, "requires a block" unless block_given?
      redis_pool.with { |conn| yield conn }
    end

    def redis_pool
      @redis_pool ||= ConnectionPool.new(timeout: 1, size: 2) { Redis.new }
    end
  end
end
