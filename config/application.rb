require_relative "boot"

require "rails"

# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
# require "action_cable/engine"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

require "rack/throttle"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bikeindex
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Use our custom error pages
    config.exceptions_app = routes
    require "draper"
    Draper::Railtie.initializers.delete_if { |initializer| initializer.name == "draper.setup_active_model_serializers" }

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    config.time_zone = "Central Time (US & Canada)" # Also set in TimeParser::DEFAULT_TIMEZONE

    # Force sql schema use so we get psql extensions
    config.active_record.schema_format = :sql

    # Disable default implicit presence validation for belongs_to relations
    config.active_record.belongs_to_required_by_default = false

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}").to_s]
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = :en
    config.i18n.available_locales = %i[en nl]
    config.i18n.fallbacks = {"en-US": :en, "en-GB": :en}

    # Throttle stuff
    config.middleware.use Rack::Throttle::Minute, max: ENV["MIN_MAX_RATE"].to_i, cache: Redis.new, key_prefix: :throttle

    # Add middleware to make i18n configuration thread-safe
    config.middleware.use I18n::Middleware

    ActiveSupport::Reloader.to_prepare do
      Doorkeeper::ApplicationsController.layout "doorkeeper"
      Doorkeeper::AuthorizationsController.layout "doorkeeper"
      Doorkeeper::AuthorizedApplicationsController.layout "doorkeeper"
    end

    config.generators do |g|
      g.factory_bot "true"
      g.helper nil
      g.decorator nil
      g.javascripts nil
      g.stylesheets nil
      g.template_engine nil
      g.serializer nil
      g.assets nil
      g.test_framework :rspec, view_specs: false, routing_specs: false, controller_specs: false
      g.system_tests nil
    end
  end
end
