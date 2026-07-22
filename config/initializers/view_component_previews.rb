# Fix ViewComponent preview 404s after Zeitwerk reloads in development.
#
# `/rails/view_components/…` resolves previews from `ViewComponent::Preview.descendants`.
# Our previews live under app/components/ (Zeitwerk-managed) and are registered by
# Lookbook, not by ViewComponent's own (empty) `previews.paths`. On each reload Zeitwerk
# unloads the preview classes, but the gem's `__vc_load_previews` uses `require`, which
# no-ops after the first load — so descendants stays empty and every preview 404s until
# a server restart.
#
# Re-resolve each preview through the autoloader instead of `require`, so a reload always
# re-registers it. `cpath_expected_at` respects our inflections (UI, API). Mirrors the
# reload fix in lookbook.rb.
if Rails.env.development?
  Rails.application.config.after_initialize do
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
