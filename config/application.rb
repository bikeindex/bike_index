require File.expand_path('../boot', __FILE__)

require 'csv'
require 'rails/all'
require 'rack/throttle'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bikeindex
  class Application < Rails::Application
    require 'draper'
    Draper::Railtie.initializers.delete_if {|initializer| initializer.name == 'draper.setup_active_model_serializers' }

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib #{config.root}/lib/jobs #{config.root}/lib/integrations)
     config.autoload_paths += Dir[ Rails.root.join('app', 'models', "concerns", '**/') ]
    config.autoload_paths += Dir[ Rails.root.join('app', 'controllers', "concerns", '**/') ]

    config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = false


    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true


    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Force sql schema use so we get sql extensions for fuzzy searching
    config.active_record.schema_format = :sql

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Send error routes the route.rb
    config.exceptions_app = self.routes
    
    config.middleware.use Rack::Throttle::Minute, :max => ENV['MIN_MAX_RATE'].to_i, :cache => Redis.new, :key_prefix => :throttle

    config.to_prepare do
      Doorkeeper::ApplicationsController.layout "doorkeeper"
      Doorkeeper::AuthorizationsController.layout "doorkeeper"
      Doorkeeper::AuthorizedApplicationsController.layout "doorkeeper"
    end
    
    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
