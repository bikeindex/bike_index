# frozen_string_literal: true

require "i18n/tasks/data/router/pattern_router"

module I18nTasks
  # Sends every `components.*` key to the sidecar of the component that owns it, which a
  # write pattern can't work out: in `components.pages.org.search.settings.address`,
  # `settings` is either another component or a nested key group of the `search` one, and
  # only the filesystem knows which. Guessing wrongly files the sidecar in a directory with
  # no component.rb, where MARKUP_DIGEST can't see it.
  #
  # Anything that isn't a component, or names a directory that doesn't exist yet, falls
  # through to the write patterns.
  class ComponentRouter < ::I18n::Tasks::Data::Router::PatternRouter
    ROOT = "app/components"

    def route(locale, forest, &block)
      return to_enum(:route, locale, forest) unless block

      locale = locale.to_s
      sidecars = Hash.new { |hash, path| hash[path] = Set.new }
      unrouted = Set.new

      forest.keys do |key, _node|
        path = sidecar_for(key, locale)
        (path ? sidecars[path] : unrouted) << "#{locale}.#{key}"
      end

      sidecars.each do |path, keys|
        block.yield path, forest.select_keys(root: true) { |key, _| keys.include?(key) }
      end

      return if unrouted.empty?

      super(locale, forest.select_keys(root: true) { |key, _| unrouted.include?(key) }, &block)
    end

    private

    # The deepest ancestor that is a component, so a nested key group stays with its owner
    def sidecar_for(key, locale)
      return unless key.start_with?("components.")

      segments = key.delete_prefix("components.").split(".")
      (segments.length - 1).downto(1) do |depth|
        directory = File.join(ROOT, *segments.first(depth))
        next unless File.exist?(File.join(directory, "component.rb"))

        return File.join(directory, "component.#{locale}.yml")
      end
      nil
    end
  end
end
