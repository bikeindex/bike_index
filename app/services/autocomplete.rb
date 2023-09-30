module Autocomplete
  STOREAGE_KEY = "autc#{Rails.env.test? ? ":test" : ""}:".freeze
  SORTED_CATEGORY_ARRAY = %w[colors cycle_type frame_mnfg mnfg].freeze
  STOP_WORDS = [].freeze # I think we might want to include 'the'

  # Every method in this module should only be accessed by the subclasses.
  # I'm not sure how to do that correctly :/
  class << self
    def cache_duration
      600 # 10 minutes
    end

    def normalize(str)
      return "" if str.blank?
      I18n.transliterate(str.downcase).gsub(/[^\p{Word}\ ]/i, '')
        .strip.gsub(/\s+/, " ")
    end

    def prefixes_for_phrase(phrase)
      normalize(phrase).split(" ").reject do |w|
        STOP_WORDS.include?(w)
      end.map do |w|
        (0..(w.length - 1)).map { |l| w[0..l] }
      end.flatten.uniq
    end

    def sorted_category_array
      # TODO: We're still putting the categories into redis - but I don't think we actually need to
      SORTED_CATEGORY_ARRAY
      # redis { |r| r.smembers(categories_id) }.map { |c| normalize(c) }.uniq.sort
    end

    def combinatored_category_array
      # Maybe use a static list?
      1.upto(sorted_category_array.size).
        flat_map do |n|
          sorted_category_array.combination(n)
            .map { |el| el.join('') }
        end
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

    def category_id(name = "all")
      "#{categories_id}#{name}:"
    end

    def no_query_id(category = nil)
      "all:#{category || category_id}"
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
  end
end
