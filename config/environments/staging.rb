# Staging inherits from production and overrides only the bits that should
# diverge for a non-production deploy.
#
# Gotcha: `Rails.env.production?` is FALSE in staging even though we require
# production here — env-conditional code paths need to check
# `Rails.env.production? || Rails.env.staging?` (see config/routes.rb,
# config/initializers/session_store.rb, config/initializers/rack_timeout.rb).
require_relative "production"

Rails.application.configure do
  # Capture every message in letter_opener_web instead of sending. The inbox is
  # mounted at /letter_opener in config/routes.rb (unrestricted — staging runs
  # seeded data with no PII). letter_opener_web is auto-required by Bundler via
  # the :staging group.
  config.action_mailer.delivery_method = :letter_opener_web

  # Persist the inbox on the storage volume (config/deploy.review.yml mounts
  # <app>_storage at /rails/storage) instead of the gem default tmp/letter_opener
  # — each deploy boots a fresh container with an empty tmp/, which would drop
  # every captured message.
  LetterOpenerWeb.configure do |letter_opener_config|
    letter_opener_config.letters_location = Rails.root.join("storage", "letter_opener")
  end

  # Upload to the dev R2 bucket so staging doesn't touch production assets
  # (see config/storage.yml).
  config.active_storage.service = :cloudflare_dev

  # Enable ActionMailer previews (/rails/mailers, linked from the admin Mailers
  # dropdown) — production-default is off. preview_paths must be set explicitly:
  # Rails only auto-adds spec/mailers/previews in development. Safe here: staging
  # runs seeded data with no PII (same rationale as the unrestricted
  # /letter_opener mount in config/routes.rb).
  config.action_mailer.show_previews = true
  config.action_mailer.preview_paths = ["#{Rails.root}/spec/mailers/previews"]

  # production.rb sends the log to stdout (for `kamal logs`) when
  # RAILS_LOG_TO_STDOUT is set — under that same condition, broadcast it to
  # log/staging.log too, so the read_logged_searches cron job (config/crontab)
  # has a file to rg. Set the formatter BEFORE wrapping in TaggedLogging (as
  # production.rb does for the stdout logger we reuse here) so the lines keep
  # the `I, [timestamp]` prefix LogSearcher::Reader matches AND tagged logging
  # keeps working (config.log_tags = [:request_id]). Setting the formatter on
  # the BroadcastLogger afterward clobbers the tagged formatters, so every
  # request's push_tags raises NoMethodError.
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    file_logger = ActiveSupport::Logger.new(Rails.root.join("log/#{Rails.env}.log"))
    file_logger.formatter = config.log_formatter
    config.logger = ActiveSupport::BroadcastLogger.new(
      config.logger, # production.rb's tagged stdout logger
      ActiveSupport::TaggedLogging.new(file_logger)
    )
  end
end
