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
    config.redis_default_url = ENV["REDIS_URL"]
    # If in test, add the TEST_ENV_NUMBER to the redis
    if config.redis_default_url.blank? && Rails.env.test? && ENV["TEST_ENV_NUMBER"].present?
      config.redis_default_url = "redis://localhost:6379/#{ENV["TEST_ENV_NUMBER"]&.to_i || 0}"
    end
    config.redis_cache_url = ENV.fetch("REDIS_CACHE_URL", config.redis_default_url)

    config.load_defaults 8.0

    # directly using Sidekiq is preferred, but some things (e.g. active_storage) use active job
    config.active_job.queue_adapter = :sidekiq
    config.active_job.default_queue_name = :low_priority

    # Use our custom error pages
    config.exceptions_app = routes

    config.time_zone = "Central Time (US & Canada)"

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks rails])

    # Force sql schema use so we get psql extensions
    config.active_record.schema_format = :sql

    # Disable default implicit presence validation for belongs_to relations
    config.active_record.belongs_to_required_by_default = false

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}").to_s]
    config.i18n.load_path += Dir[Rails.root.join("app", "components", "**", "*.{yml}").to_s]
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = :en
    config.i18n.available_locales = %i[en es it nl nb]
    config.i18n.fallbacks = {"en-US": :en, "en-GB": :en}

    config.middleware.insert 0, Rack::UTF8Sanitizer
    config.middleware.use Rack::Throttle::Minute,
      max: ENV["MIN_MAX_RATE"].to_i,
      cache: Redis.new(url: config.redis_cache_url),
      key_prefix: :throttle

    # Add middleware to make i18n configuration thread-safe
    config.middleware.use I18n::Middleware

    ActiveSupport::Reloader.to_prepare do
      Doorkeeper::ApplicationsController.layout "doorkeeper"
      Doorkeeper::AuthorizationsController.layout "doorkeeper"
      Doorkeeper::AuthorizedApplicationsController.layout "doorkeeper"
    end

    # Enable instrumentation for ViewComponents (used by rack-mini-profiler)
    config.view_component.instrumentation_enabled = true
    config.view_component.use_deprecated_instrumentation_name = false # Stop annoying deprecation message
    # ^ remove after upgrading to ViewComponent 4
    config.default_preview_layout = "component_preview"
    config.view_component.preview_paths = "#{Rails.root}/app/components/"
    # This is ugly but necessary, see github.com/ViewComponent/view_component/issues/1064
    initializer "app_assets", after: "importmap.assets" do
      Rails.application.config.assets.paths << Rails.root.join("app")
    end
    config.importmap.cache_sweepers << Rails.root.join("app/components") # Sweep importmap cache
    config.lookbook.preview_display_options = {theme: ["light", "dark"]} # Add dynamic 'theme' display option

    config.generators do |g|
      g.helper nil
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
