require "active_support/core_ext/integer/time"

Rails.application.configure do
  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Enable server timing
  config.server_timing = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp", "caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.cache_store = :redis_cache_store, {url: config.redis_cache_url}

    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  config.action_mailer.perform_caching = false
  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = if ENV["CLOUDFLARE_DEV"] == "true"
    :cloudflare_dev
  else
    :local
  end

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {host: "localhost", port: 3042}
  routes.default_url_options = config.action_mailer.default_url_options
  if Rails.root.join("tmp", "skip-letter_opener.txt").exist?
    config.action_mailer.perform_deliveries = false
    config.action_mailer.delivery_method = :smtp
  else
    config.action_mailer.perform_deliveries = true
    config.action_mailer.delivery_method = :letter_opener
  end

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log
  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true
  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

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

  # Lograge is what we use in production, it makes requests create one log line, rather than the multitude created by default
  # Useful to turn off primarily to monitor caching
  # Run rails dev:lograge to toggle lograge. It's enabled by default
  unless Rails.root.join("tmp", "non-lograge-dev.txt").exist?
    config.lograge.enabled = true
    config.log_level = :debug
    config.lograge.formatter = Lograge::Formatters::Logstash.new # Use logstash format
    config.lograge.custom_options = lambda do |event|
      {
        remote_ip: event.payload[:ip],
        u_id: event.payload[:u_id],
        params: event.payload[:params]&.except("controller", "action", "format", "id")
      }
    end
  end

  # Bullet for n+1's
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true
  end

  # Raises error for missing translations
  config.i18n.raise_on_missing_translations = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
