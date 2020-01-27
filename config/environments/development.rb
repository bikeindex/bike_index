Rails.application.configure do
  # Verifies that versions and hashed value of the package contents in the
  # project's package.json
  config.webpacker.check_yarn_integrity = true

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rake dev:cache to toggle caching in development
  if Rails.root.join("tmp", "caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.cache_store = :dalli_store, {
      namespace: Bikeindex,
      expires_in: 0,
      compress: true,
    }

    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=172800",
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  config.action_mailer.perform_caching = false

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: "localhost", port: 3001 }
  if Rails.root.join("tmp", "skip-letter_opener.txt").exist?
    config.action_mailer.perform_deliveries = false
    config.action_mailer.delivery_method = :smtp
  else
    config.action_mailer.perform_deliveries = true
    config.action_mailer.delivery_method = :letter_opener
  end

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  config.lograge.enabled = true
  config.log_level = :debug
  config.lograge.formatter = Lograge::Formatters::Logstash.new # Use logstash format
  config.lograge.custom_options = lambda do |event|
    {
      remote_ip: event.payload[:ip],
      params: event.payload[:params].except("controller", "action", "format", "id"),
    }
  end

  # Bullet for n+1's
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true
  end

  # Raises error for missing translations
  config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Make sure we reload the API after every request!
  @last_api_change = Time.current
  api_reloader = ActiveSupport::FileUpdateChecker.new(Dir["#{Rails.root}/app/controllers/api/v2/**/*.rb"]) do |reloader|
    times = Dir["#{Rails.root}/app/api/**/*.rb"].map { |f| File.mtime(f) }
    files = Dir["#{Rails.root}/app/api/**/*.rb"].map { |f| f }

    Rails.logger.debug "! Change detected: reloading following files:"
    files.each_with_index do |s, i|
      if times[i] > @last_api_change
        Rails.logger.debug " - #{s}"
        load s
      end
    end

    Rails.application.reload_routes!
    Rails.application.routes_reloader.reload!
    Rails.application.eager_load!
  end

  ActiveSupport::Reloader.to_prepare do
    api_reloader.execute_if_updated
  end
end
