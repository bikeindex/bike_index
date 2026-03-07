# https://lookbook.build/guide/ui/theming

Lookbook.configure do |config|
  config.ui_theme = "blue"
  config.ui_theme_overrides = {header_bg: "#3498db"}
  config.preview_paths = ["#{Rails.root}/app/components/"]
end

# Provide sort_column/sort_direction defaults for preview rendering
# (normally set by SortableTable concern in controllers)
Rails.application.config.after_initialize do
  [Lookbook::PreviewController, ViewComponentsController].each do |controller|
    next unless defined?(controller)
    controller.helper do
      def sort_column = "id"
      def sort_direction = "desc"
    end
  end
end
