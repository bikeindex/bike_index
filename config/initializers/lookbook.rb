# https://lookbook.build/guide/ui/theming

Lookbook.configure do |config|
  config.ui_theme = "blue"
  config.ui_theme_overrides = {header_bg: "#3498db"}
  config.preview_paths = ["#{Rails.root}/app/components/"]
end

# Append the review-app topbar's title to the navbar, so a Lookbook tab is
# identifiable as dev/sandbox/a PR. after_initialize because component
# translations aren't on the I18n load path while initializers run.
Rails.application.config.after_initialize do
  title = SharedBlocks::ReviewAppBanner::Component.from_env.lookbook_navbar_title
  Lookbook.config.project_name = ["Bike Index", title].compact.join(" · ")
end

# Fix preview breakage during development code reloading. Both patches re-resolve
# preview classes through the autoloader after Zeitwerk unloads constants on reload.
if Rails.env.development?
  Rails.application.config.after_initialize do
    # Lookbook caches preview class objects in PreviewEntity, but only refreshes
    # previews for files that changed. After Zeitwerk unloads ALL constants, the
    # unchanged previews hold stale class references whose module namespaces no
    # longer have autoloads configured - causing constant resolution failures
    # (e.g. `Component` resolving to the AR model instead of the view component).
    # Forcing re-resolution on every access always returns the current class.
    Lookbook::PreviewEntity.class_eval do
      def preview_class
        @code_object.path.constantize
      rescue NameError
        @preview_class
      end
    end

    # `/rails/view_components/…` resolves previews from `ViewComponent::Preview.descendants`.
    # Our previews live under app/components/ and are registered by Lookbook, not by
    # ViewComponent's own (empty) `previews.paths`. The gem's `__vc_load_previews` reloads
    # via `require`, which no-ops after the first load — so once a reload unloads them,
    # descendants stays empty and every preview 404s until a server restart. Re-resolve
    # through the autoloader instead (`cpath_expected_at` respects our UI/API inflections).
    ViewComponent::Preview.singleton_class.class_eval do
      def __vc_load_previews
        Dir[Rails.root.join("app/components/**/*_preview.rb")].each do |file|
          Rails.autoloaders.main.cpath_expected_at(file)&.constantize
        rescue NameError
          nil
        end
      end
    end
  end
end
