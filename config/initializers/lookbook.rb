# https://lookbook.build/guide/ui/theming

Lookbook.configure do |config|
  config.ui_theme = "blue"
  config.ui_theme_overrides = {header_bg: "#3498db"}
  config.preview_paths = ["#{Rails.root}/app/components/"]
end
