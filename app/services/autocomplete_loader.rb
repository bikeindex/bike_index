class AutocompleteLoader
  def clear
    Soulheart::Loader.new.clear(true)
  end

  def clear_cache
    # Doesn't work correctly because it doesn't regenerate the categories afterward
    # This is a bug in Soulheart
    Soulheart::Loader.new.clear_cache
  end

  def reset
    clear
    load_colors
    load_cycle_types
    load_manufacturers
  end

  def load_colors
    Soulheart::Loader.new.load(Color.all.map { |c| c.autocomplete_hash })
  end

  def load_cycle_types
    Soulheart::Loader.new.load(CycleType.all.map { |c| c.autocomplete_hash })
  end

  def load_manufacturers
    mnfgs_list = []
    Manufacturer.find_each { |m| mnfgs_list << m.autocomplete_hash }
    Soulheart::Loader.new.load(mnfgs_list)
  end
end
