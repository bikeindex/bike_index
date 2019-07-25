# frozen_string_literal: true

module CacheHelper
  # Override ActionView `cache` helper, adding the current locale to the cache
  # key.
  def cache(key = {}, options = {}, &block)
    super([key, locale: I18n.locale], options, &block)
  end
end
