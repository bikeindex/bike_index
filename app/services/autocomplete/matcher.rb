class Autocomplete::Matcher
  DEFAULT_PARAMS = {
    page: 1,
    per_page: 5,
    categories: [],
    q: "", # Query
    cache: true
  }.freeze

  class << self
    def search(pparms = {}, opts = nil)
      opts ||= params_to_opts(pparms)
      # It always responds with the cache - if cache: false, store the cache - or, if there isn't a cached
      if !opts[:cache] || not_in_cache?(opts[:cache_key])
        store_search_in_cache(opts[:cache_key], opts[:interkeys])
      end
      terms = RedisPool.conn { |r| r.zrange(opts[:cache_key], opts[:offset], opts[:limit]) }
      matching_hashes(terms)
    end

    def params_to_opts(pparms = {})
      per_page = pparms.dig(:per_page)&.to_i || DEFAULT_PARAMS[:per_page]
      page = pparms.dig(:page)&.to_i || DEFAULT_PARAMS[:page]
      offset = (page - 1) * per_page
      limit = per_page + offset - 1
      categories = categories_array(pparms[:categories])

      opts = {
        categories: categories,
        q_array: query_array(pparms[:q]),
        category_cache_key: category_key_from_opts(categories)
      }
      opts.merge(
        cache: pparms[:cache].present? ? Binxtils::InputNormalizer.boolean(pparms[:cache]) : DEFAULT_PARAMS[:cache],
        cache_key: cache_key_from_opts(categories, opts[:q_array]),
        interkeys: interkeys_from_opts(opts[:category_cache_key], opts[:q_array]),
        offset: offset,
        limit: (limit < 0) ? 0 : limit
      )
    end

    private

    def not_in_cache?(cache_key)
      cached_result = RedisPool.conn { |r| r.exists(cache_key) }
      cached_result.blank? || cached_result == 0
    end

    def query_array(query)
      if query.is_a?(Array)
        query.map { |q| Autocomplete.normalize(q) }
      else
        Autocomplete.normalize(query).split(" ")
      end
    end

    def categories_array(categories = [])
      return [] if categories.blank?

      categories = categories.split(/,|\+/) if !categories.is_a?(Array)
      permitted_categories = Autocomplete.sorted_category_array
      categories = permitted_categories & categories.map { |s| Autocomplete.normalize(s) }
      return [] if categories.length == permitted_categories.length

      categories
    end

    def total_categories_count
      # Can be a static call, now that categories are static
      Autocomplete.sorted_category_array.count
    end

    def categories_string(categories)
      categories.empty? ? "all" : categories.join("")
    end

    def category_key_from_opts(categories)
      Autocomplete.category_key(categories_string(categories))
    end

    def cache_key_from_opts(categories, q_array)
      [
        Autocomplete.cache_key(categories_string(categories)),
        q_array.join(":")
      ].reject(&:blank?).join("")
    end

    def interkeys_from_opts(category_cache_key, q_array)
      # If there isn't a query, we use a special key in redis
      if q_array.empty?
        [Autocomplete.no_query_key(category_cache_key)]
      else
        q_array.map { |w| "#{category_cache_key}#{w}" }
      end
    end

    def store_search_in_cache(cache_key, interkeys)
      RedisPool.conn do |r|
        r.zinterstore(cache_key, interkeys)
        r.expire(cache_key, Autocomplete.cache_duration)
      end
    end

    def matching_hashes(terms)
      return [] unless terms.size > 0

      RedisPool.conn { |r| r.hmget(Autocomplete.items_data_key, *terms) }
        .reject(&:blank?).map { |r| JSON.parse(r) }
    end
  end
end
