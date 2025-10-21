# frozen_string_literal: true

if Rails.env.development?
  ReActionView.configure do |config|
    # Intercept .html.erb templates and process them with `Herb::Engine` for enhanced features
    config.intercept_erb = true

    # Enable debug mode in development (adds debug attributes to HTML)
    config.debug_mode = true
  end
end
