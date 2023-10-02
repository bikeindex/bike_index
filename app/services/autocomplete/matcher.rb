class Autocomplete::Matcher
  DEFAULT_PARAMS = {
    page: 1,
    per_page: 5,
    categories: [],
    q: "", # Query
    cache: true
  }.freeze

  class << self
    def search(pparms = {})
      sparams = search_params(pparms)
      if sparams[:cache]
        # !redis.exists(@cachekey) || redis.exists(@cachekey) == 0
        cache_it_because(sparams[:cache_id], sparams[:interkeys])
      end

      terms = redis { |r| r.zrange(sparams[:cache_id], sparams[:offset], sparams[:limit]) }
      matching_hashes(terms)
    end

    private

    def search_params(pparms = {})
      sparams = {
        categories: categories_array(pparms[:categories]),
        q_array: query_array(pparms[:q]),
        cache: pparms[:cache].present? ? ParamsNormalizer.boolean(pparms[:cache]) : DEFAULT_PARAMS[:cache]
      }
      per_page = pparms.dig(:per_page)&.to_i || DEFAULT_PARAMS[:per_page]
      page = pparms.dig(:page)&.to_i || DEFAULT_PARAMS[:page]
      sparams[:offset] = (page - 1) * per_page
      limit = per_page + sparams[:offset] - 1
      sparams[:limit] = limit < 0 ? 0 : limit
      sparams[:cache_id] = cache_id_from_opts(sparams[:categories], sparams[:q_array])
      return sparams unless sparams[:cache]
      sparams[:category_cache_id] = category_id_from_opts(sparams[:categories])
      sparams[:interkeys] = interkeys_from_opts(sparams[:category_cache_id], sparams[:q_array])
      sparams
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
      categories = categories.map { |s| Autocomplete.normalize(s) }.uniq.sort
      if categories.length > 1 && categories.length == total_categories_count
        categories = []
      end
      categories
    end

    def total_categories_count
      # Can be a static call, now that categories are static
      Autocomplete.sorted_category_array.count
    end

    def categories_string(categories)
      categories.empty? ? "all" : categories.join("")
    end

    def category_id_from_opts(categories)
      Autocomplete.category_id(categories_string(categories))
    end

    def cache_id_from_opts(categories, q_array)
      [
        Autocomplete.cache_id(categories_string(categories)),
        q_array.join(":")
      ].reject(&:blank?).join("")
    end

    def interkeys_from_opts(category_cache_id, q_array)
      # If there isn't a query, we use a special key in redis
      if q_array.empty?
        [Autocomplete.no_query_id(category_cache_id)]
      else
        q_array.map { |w| "#{category_cache_id}#{w}" }
      end
    end

    def cache_it_because(cache_id, interkeys)
      Autocomplete.redis do |r|
        r.zinterstore(cache_id, interkeys)
        r.expire(cache_id, Autocomplete.cache_duration)
      end
    end

    def matching_hashes(terms)
      return [] unless terms.size > 0
      redis { |r| r.hmget(results_hashes_id, *terms) }
        .reject(&:blank?).map { |r| JSON.parse(r) }
    end
  end
end
