Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Don't log things in test
  config.active_record.verbose_query_logs = false
  config.active_record.query_log_tags_enabled = false
  config.log_level = :fatal

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  # Don't check for precompiled assets
  config.assets.check_precompiled_asset = false

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []
  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Raises error for missing translations
  config.i18n.raise_on_missing_translations = true
  config.i18n.exception_handler = proc { |exception| raise exception.to_exception }

  config.action_mailer.default_url_options = {host: ENV["BASE_URL"]}
  routes.default_url_options = config.action_mailer.default_url_options

  config.cache_store = :file_store, Rails.root.join("tmp", "cache", "test#{ENV["TEST_ENV_NUMBER"]}")

  # Configure Sidekiq to suppress INFO logs in test environment
  if defined?(Sidekiq)
    Sidekiq.configure_client { |config| config.logger.level = Logger::WARN }

    Sidekiq.configure_server { |config| config.logger.level = Logger::WARN }
  end
end
