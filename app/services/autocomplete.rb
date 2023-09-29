module Autocomplete
  STOREAGE_KEY = "autc#{Rails.env.test? ? ":test" : ""}:".freeze

  class << self
    def cache_duration
      600 # 10 minutes
    end

    def normalize(str)
      return "" if str.blank?
      I18n.transliterate(str.downcase).gsub(/[^\p{Word}\ ]/i, '')
        .strip.gsub(/\s+/, " ")
    end

    # TODO: we have a static list of categories, we don't need to query redis for them
    def sorted_category_array
      redis { |r| r.smembers(categories_id) }
        .map { |c| normalize(c) }.uniq.sort
    end

    def hidden_category_array
      redis { |r| r.smembers(hidden_categories_id) }
        .map { |c| normalize(c) }.uniq.sort
    end

    def combinatored_category_array
      1.upto(sorted_category_array.size).
        flat_map do |n|
          sorted_category_array.combination(n)
            .map { |el| el.join('') }
        end
    end

    # I don't think this belongs in the module...
    def set_category_combos_array
      redis { |r| r.expire(category_combos_id, 0) }
      array = combinatored_category_array
      # IDK why, original code replaced the last element of the array with 'all'
      # array.any? ? array.last.replace('all') : array << 'all'
      array = ["all"] if array.none?
      redis { |r| r.sadd(category_combos_id, array) }
      array
    end

    def category_combos_id
      "#{STOREAGE_KEY}category_combos:"
    end

    def category_combos
      redis { |r| r.smembers(category_combos_id) }
    end

    def categories_id
      "#{STOREAGE_KEY}cts:"
    end

    def hidden_categories_id
      "#{categories_id}h:"
    end

    def category_id(name = "all")
      "#{categories_id}#{name}:"
    end

    def no_query_id(category = category_id)
      "all:#{category}"
    end

    def results_hashes_id
      "#{STOREAGE_KEY}db:"
    end

    def cache_id(type = "all")
      "#{STOREAGE_KEY}cache:#{type}:"
    end

    # Should be the canonical way of using redis
    def redis
      # Basically, crib what is done in sidekiq
      raise ArgumentError, "requires a block" unless block_given?
      redis_pool.with { |conn| yield conn }
    end

    def redis_pool
      @redis_pool ||= ConnectionPool.new(timeout: 1, size: 2) { Redis.new }
    end

    protected
  end
end
