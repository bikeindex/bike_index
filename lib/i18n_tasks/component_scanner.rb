# frozen_string_literal: true

require "i18n/tasks/scanners/pattern_scanner"

module I18nTasks
  # Finds the `translation("key")` calls that ApplicationComponent defines, which the stock
  # scanners don't recognise. It always passes a `scope:`, so the leading dot other Rails
  # helpers need is optional here and the key is never top-level; the scope comes from the
  # class name, which Zeitwerk makes the same answer as the component's directory.
  #
  # scope_overrides carries the components that deliberately read someone else's scope.
  class ComponentScanner < ::I18n::Tasks::Scanners::PatternScanner
    ROOT = "app/components"

    def absolute_key(key, path, **_options)
      "#{scope_for(path)}.#{key.delete_prefix(".")}"
    end

    private

    def scope_for(path)
      directory = File.dirname(File.expand_path(path))
        .delete_prefix("#{File.expand_path(ROOT)}#{File::SEPARATOR}")

      scope_overrides[directory] || "components.#{directory.tr(File::SEPARATOR, ".")}"
    end

    def scope_overrides
      @scope_overrides ||= (config[:scope_overrides] || {}).transform_keys(&:to_s)
    end
  end
end
