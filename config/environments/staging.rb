require "active_support/core_ext/integer/time"

# Staging is a near-duplicate of config/environments/production.rb — keep it
# in sync when production changes. The only intentional divergence is that
# ActionMailer routes through letter_opener_web (no Postmark / SendGrid) so
# staging review apps never send real email.
#
# Used by per-PR review apps (config/deploy.review.yml sets RAILS_ENV=staging);
# real production runs on Cloud66 with RAILS_ENV=production.
Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  # Use lograge for logging
  config.lograge.enabled = true
  config.log_level = :info
  config.lograge.formatter = Lograge::Formatters::Logstash.new # Use logstash format
  config.lograge.custom_options = lambda do |event|
    {
      remote_ip: event.payload[:ip],
      u_id: event.payload[:u_id],
      params: event.payload[:params].except("controller", "action", "format", "id")
    }
  end

  # Log times where people pass non-permitted params
  config.action_controller.action_on_unpermitted_parameters :log

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.cache_store = :redis_cache_store, {url: config.redis_cache_url}

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Store uploads in the dev R2 bucket so staging review apps don't touch
  # production assets (see config/storage.yml).
  config.active_storage.service = :cloudflare_dev

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true
  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  config.action_mailer.perform_caching = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = [I18n.default_locale]

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  base_url = URI.parse(ENV.fetch("BASE_URL"))
  config.action_mailer.default_url_options = {protocol: base_url.scheme, host: base_url.host}
  routes.default_url_options = config.action_mailer.default_url_options

  # Capture every message in letter_opener_web instead of sending. The inbox is
  # mounted at /letter_opener in config/routes.rb (behind DeveloperRestriction).
  # letter_opener_web is auto-required by Bundler via the :staging group.
  config.action_mailer.delivery_method = :letter_opener_web

  # Only use :id for inspections.
  config.active_record.attributes_for_inspect = [:id]
end
