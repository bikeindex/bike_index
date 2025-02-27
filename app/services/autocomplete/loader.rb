class Autocomplete::Loader
  DEFAULT_ITEM = {
    category: "default",
    priority: 100,
    term: nil,
    data: {}
  }.freeze

  class << self
    # Generally, the cache should be cleared, but it doesn't need to be cleared if just adding new data
    def clear_redis(skip_clearing_cache = false)
      delete_categories_and_item_data
      delete_data
      # Clear cache at the end, to reduce disruption (hopefully the majority of the cache matches)
      clear_cache unless skip_clearing_cache
    end

    def load_all(kinds = nil, print_counts: false)
      store_category_combos
      kinds ||= %w[Color CycleType Manufacturer PropulsionType]
      total_count = 0

      if kinds.include?("Color")
        colors_count = store_items(Color.all.map { |c| c.autocomplete_hash })
        total_count += colors_count
        if print_counts
          puts "Total Colors added (including combinatorial categories):         #{colors_count}"
        end
      end

      if kinds.include?("PropulsionType")
        pro_count = store_items(PropulsionType.autocomplete_hashes)
        total_count += pro_count
        if print_counts
          puts "Total Propulsion Types added (including combinatorial categories):         #{pro_count}"
        end
      end

      if kinds.include?("CycleType")
        c_type_count = store_items(CycleType.all.map { |c| c.autocomplete_hash })
        total_count += c_type_count
        if print_counts
          puts "Total Cycle Types added (including combinatorial categories):    #{c_type_count}"
        end
      end

      # TODO: find in batches
      if kinds.include?("Manufacturer")
        mnfg_count = store_items(Manufacturer.all.map { |m| m.autocomplete_hash })
        total_count += mnfg_count
        if print_counts
          puts "Total Manufacturers added (including combinatorial categories):  #{mnfg_count}"
        end
      end

      puts "Total added:                                                     #{total_count}" if print_counts
      total_count
    end

    def info
      RedisPool.conn do |r|
        # NOTE: if you add in more DBs, include the keys here
        included_info = r.info.slice("used_memory_human", "used_memory_peak_human", "db0")
          .map { |k, v| [k.gsub("_human", "").to_sym, v] }.to_h
        {
          category_keys: fetch_category_keys(r).count,
          cache_keys: fetch_cache_keys(r).count
        }.merge(included_info)
      end
    end

    def frame_mnfg_count
      RedisPool.conn do |r|
        r.scan_each(match: "#{Autocomplete.category_key("frame_mnfg")}*")
      end.count
    end

    private

    def store_items(items)
      i = 0
      items = items.map { |i| clean_hash(i) }
      combinatored_category_array.each do |category_combo|
        items.each do |item|
          next unless category_combo.match?(item[:category]) || category_combo == "all"
          # Only add item data once (when in the exact matching category)
          store_item(item, Autocomplete.category_key(category_combo), category_combo != item[:category])
          i += 1
        end
      end
      i
    end

    def store_item(item, category_base_key = nil, skip_item_data = false)
      category_base_key ||= Autocomplete.category_key(item[:category])
      priority = -1 * item[:priority]
      # pipeline doesn't reduce network requests, my understanding is wrapping all (as oppose to individual items)
      # in pipeline wouldn't improve functionality and might actually cause longer blocking
      RedisPool.conn do |r|
        r.pipelined do |pipeline|
          # Add to master set for queryless searches
          pipeline.zadd(Autocomplete.no_query_key(category_base_key), priority, item[:term])
          # store the raw data in a separate key (no need to have for each category)
          pipeline.hset(Autocomplete.items_data_key, item[:term], item[:data].to_json) unless skip_item_data
          # Store all the prefixes
          prefixes_for_phrase(item[:term]).each do |prefix|
            pipeline.sadd(base_key, prefix) unless skip_item_data # remember prefix in a master set
            # store the normalized term in the index for each of the categories
            pipeline.zadd("#{category_base_key}#{prefix}", priority, item[:term])
          end
        end
      end
      item
    end

    def base_key
      Autocomplete::BASE_KEY
    end

    def prefixes_for_phrase(phrase)
      Autocomplete.normalize(phrase).split(" ").reject do |w|
        Autocomplete::STOP_WORDS.include?(w)
      end.map do |w|
        (0..(w.length - 1)).map { |l| w[0..l] }
      end.flatten.uniq
    end

    # Assume this is memoized, during load_all - so use it instead of #category_combos
    def combinatored_category_array
      return @combinatored_category_array if defined?(@combinatored_category_array)
      array = 1.upto(Autocomplete.sorted_category_array.size).flat_map do |n|
        Autocomplete.sorted_category_array.combination(n)
          .map { |el| el.join("") }
      end
      array.last.replace("all") # Last category is the combination of every one
      @combinatored_category_array = array
    end

    def store_category_combos
      RedisPool.conn do |r|
        r.sadd(Autocomplete.category_combos_key, combinatored_category_array)
      end
    end

    def items_hash(text, category = "default")
      i_hash = DEFAULT_ITEM.merge(term: Autocomplete.normalize(text), category: Autocomplete.normalize(category))
      i_hash.merge(data: {text: text, category: i_hash[:category]})
    end

    def clean_hash(item)
      if item[:text].blank?
        raise ArgumentError, "Items must have text. Missing from: #{item}"
      end
      i_hash = items_hash(item[:text], item[:category])
      unless Autocomplete.sorted_category_array.include?(i_hash[:category])
        raise ArgumentError, "Items must have one of the accepted categories, not included in: #{item}"
      end
      i_hash[:data] = i_hash[:data].merge(item[:data]) if item[:data].present?
      i_hash[:priority] = item[:priority].to_f if item[:priority].present?
      i_hash[:data][:id] = item[:id] if item[:id].present?
      i_hash
    end

    def clear_cache
      RedisPool.conn do |r|
        # can't be pipelined, requires the response
        keys = fetch_cache_keys(r).to_a

        r.pipelined do |pipeline|
          keys.each { |k| pipeline.expire(k, 0) }
        end
      end
    end

    def delete_categories_and_item_data
      RedisPool.conn do |r|
        # Get all the matching keys for category typeahead
        keys = fetch_category_keys(r).to_a

        r.pipelined do |pipeline|
          # Use static categories, so it doesn't rely on data in Redis
          combinatored_category_array.each do |cat|
            pipeline.expire(Autocomplete.no_query_key(Autocomplete.category_key(cat)), 0)
          end
          pipeline.expire(Autocomplete.category_combos_key, 0)

          # Delete the items data values
          # pipeline.expire(Autocomplete.items_data_key, 0)
          pipeline.del(Autocomplete.items_data_key)

          # Expire all the typeahead keys
          keys.each { |k| pipeline.expire(k, 0) }
        end
      end
    end

    def fetch_category_keys(redis_block)
      redis_block.scan_each(match: Autocomplete.category_key.gsub(/all:\z/, "*"))
    end

    def fetch_cache_keys(redis_block)
      redis_block.scan_each(match: Autocomplete.cache_key.gsub(/all:\z/, "*"))
    end

    def delete_data(id = nil)
      id ||= "#{base_key}:"
      # delete the sorted sets for this type
      RedisPool.conn do |r|
        phrases = r.smembers(base_key)
        r.pipelined do |pipeline|
          phrases.each { |phrase| pipeline.del("#{id}#{phrase}") }
          pipeline.del(id)
        end
      end
      # Redis can continue serving cached requests while the reload is
      # occurring. Some requests may be cached incorrectly as empty set (for requests
      # which come in after the above delete, but before the loading completes). But
      # everything will work itself out as soon as the cache expires again.
    end
  end
end
