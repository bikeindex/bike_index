# Staging inherits from production and overrides only the bits that should
# diverge for review apps. See config/deploy.review.yml (RAILS_ENV=staging).
#
# Gotcha: `Rails.env.production?` is FALSE in staging even though we require
# production here — env-conditional code paths need to check
# `Rails.env.production? || Rails.env.staging?` (see config/routes.rb,
# config/initializers/session_store.rb, config/initializers/rack_timeout.rb).
require_relative "production"

Rails.application.configure do
  # Capture every message in letter_opener_web instead of sending. The inbox is
  # mounted at /letter_opener in config/routes.rb (unrestricted — staging has no PII).
  # letter_opener_web is auto-required by Bundler via the :staging group.
  config.action_mailer.delivery_method = :letter_opener_web

  # Upload to the dev R2 bucket so staging review apps don't touch production
  # assets (see config/storage.yml).
  config.active_storage.service = :cloudflare_dev

  # production.rb sends the log to stdout (for `kamal logs`) when
  # RAILS_LOG_TO_STDOUT is set. Also write it to log/staging.log so the
  # read_logged_searches cron job (config/crontab) has a file to rg. Both sinks
  # use the inherited formatter so the lines keep the `I, [timestamp]` prefix
  # LogSearcher::Reader matches.
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    config.logger = ActiveSupport::BroadcastLogger.new(
      ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout)),
      ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(Rails.root.join("log/#{Rails.env}.log")))
    ).tap { it.formatter = config.log_formatter }
  end
end
