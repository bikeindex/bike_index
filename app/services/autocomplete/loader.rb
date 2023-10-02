class Autocomplete::Loader
  DEFAULT_ITEM = {
    category: "default",
    priority: 100,
    term: nil,
    data: {}
  }.freeze

  class << self
    def clear_redis(should_clear_cache = false)
      clear_cache if should_clear_cache
      delete_categories
      delete_data
    end

    def load_all
      clear_redis
      store_category_combos
      colors_count = store_items(Color.all.map { |c| c.autocomplete_hash })
      puts "Total Colors added (including combinatorial categories):         #{colors_count}"

      c_type_count = store_items(CycleType.all.map { |c| c.autocomplete_hash })
      puts "Total Cycle Types added (including combinatorial categories):    #{c_type_count}"

      # TODO: find in batches
      mnfg_count = store_items(Manufacturer.all.map { |m| m.autocomplete_hash })
      puts "Total Manufacturers added (including combinatorial categories):  #{mnfg_count}"
      total_count = colors_count + c_type_count + mnfg_count

      puts "Total added:                                                     #{total_count}"
      total_count
    end

    private

    def store_items(items)
      i = 0
      items = items.map { |i| clean_hash(i) }
      combinatored_category_array.each do |category_combo|
        items.each do |item|
          if category_combo == item[:category]
            store_item(item)
            i += 1
          elsif category_combo.match?(item[:category])
            store_item(item, Autocomplete.category_id(category_combo), true)
            i += 1
          end
        end
      end
      i
    end

    def store_item(item, category_base_id = nil, base_added = false)
      category_base_id ||= Autocomplete.category_id(item[:category])
      priority = -1 * item[:priority]
      Autocomplete.redis do |r|
        r.pipelined do |pipeline|
          # Add to master set for queryless searches
          pipeline.zadd(Autocomplete.no_query_id(category_base_id), priority, item[:term])
          # store the raw data in a separate key to reduce memory usage
          pipeline.hset(Autocomplete.results_hashes_id, item[:term], item[:data].to_json) unless base_added
          # Store all the prefixes
          prefixes_for_phrase(item[:term]).each do |prefix|
            pipeline.sadd(base_key, prefix) unless base_added # remember prefix in a master set
            # store the normalized term in the index for each of the categories
            pipeline.zadd("#{category_base_id}#{prefix}", priority, item[:term])
          end
        end
      end
      item
    end

    def base_key
      Autocomplete::STOREAGE_KEY
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
      Autocomplete.redis do |r|
        r.sadd(Autocomplete.category_combos_id, combinatored_category_array)
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

    # Shouldn't be called independently from clearing and reloading - it breaks categories
    def clear_cache
      Autocomplete.redis do |r|
        # Remove the remove_results_hash
        # has to be called before the cat_ids are cleared
        Autocomplete.category_combos.each do |cat|
          r.expire(Autocomplete.no_query_id(Autocomplete.category_id(cat)), 0)
        end

        r.expire(Autocomplete.results_hashes_id, 0)
        r.del(Autocomplete.results_hashes_id)
      end
    end

    def delete_categories
      Autocomplete.redis do |r|
        r.expire Autocomplete.category_combos_id, 0
      end
    end

    def delete_data(id = nil)
      id ||= "#{base_key}:"
      # delete the sorted sets for this type
      Autocomplete.redis do |r|
        phrases = r.smembers(base_key)
        r.pipelined do |pipeline|
          phrases.each { |phrase| pipeline.del("#{id}#{phrase}") }
        end
        r.del(id)
      end
      # Redis can continue serving cached requests while the reload is
      # occurring. Some requests may be cached incorrectly as empty set (for requests
      # which come in after the above delete, but before the loading completes). But
      # everything will work itself out as soon as the cache expires again.
    end
  end
end
