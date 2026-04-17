# https://lookbook.build/guide/ui/theming

Lookbook.configure do |config|
  config.ui_theme = "blue"
  config.ui_theme_overrides = {header_bg: "#3498db"}
  config.preview_paths = ["#{Rails.root}/app/components/"]
end

# Fix stale class references during development code reloading.
#
# Lookbook caches preview class objects in PreviewEntity, but only refreshes
# previews for files that changed. After Zeitwerk unloads ALL constants, the
# unchanged previews hold stale class references whose module namespaces no
# longer have autoloads configured - causing constant resolution failures
# (e.g. `Component` resolving to the AR model instead of the view component).
#
# This forces preview_class to re-resolve on every access in development,
# so it always returns the current class from the autoloader.
Rails.application.config.after_initialize do
  next unless Rails.env.development?

  Lookbook::PreviewEntity.class_eval do
    def preview_class
      @code_object.path.constantize
    rescue NameError
      @preview_class
    end
  end
end
