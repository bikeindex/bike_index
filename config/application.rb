require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'rack/throttle'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bikeindex
  class Application < Rails::Application
    require 'draper'
    Draper::Railtie.initializers.delete_if {|initializer| initializer.name == 'draper.setup_active_model_serializers' }
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths << Rails.root.join('lib/')
    config.autoload_paths << Rails.root.join('lib/integrations')

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    config.time_zone = 'Central Time (US & Canada)'

    # Force sql schema use so we get psql extensions
    config.active_record.schema_format = :sql

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en
    config.i18n.enforce_available_locales = false

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # Throttle stuff
    config.middleware.use Rack::Throttle::Minute, :max => ENV['MIN_MAX_RATE'].to_i, :cache => Redis.new, :key_prefix => :throttle

    config.to_prepare do
      Doorkeeper::ApplicationsController.layout 'doorkeeper'
      Doorkeeper::AuthorizationsController.layout 'doorkeeper'
      Doorkeeper::AuthorizedApplicationsController.layout 'doorkeeper'
    end
    
    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
