Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.


  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :dalli_store,
    { namespace: Bikeindex, expires_in: 0, compress: true }

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.smtp_settings = {
    address: 'localhost',
    port: 1025
  }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Make sure we reload the API after every request!
  @last_api_change = Time.now
  api_reloader = ActiveSupport::FileUpdateChecker.new(Dir["#{Rails.root}/app/controllers/api/v2/**/*.rb"]) do |reloader|
    times = Dir["#{Rails.root}/app/api/**/*.rb"].map{|f| File.mtime(f) }
    files = Dir["#{Rails.root}/app/api/**/*.rb"].map{|f| f }

    Rails.logger.debug '! Change detected: reloading following files:'
    files.each_with_index do |s,i|
      if times[i] > @last_api_change
        Rails.logger.debug " - #{s}"
        load s 
      end
    end

    Rails.application.reload_routes!
    Rails.application.routes_reloader.reload!
    Rails.application.eager_load!
  end

  ActionDispatch::Reloader.to_prepare do
    api_reloader.execute_if_updated
  end
end
