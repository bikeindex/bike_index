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
  # mounted at /letter_opener in config/routes.rb (behind DeveloperRestriction).
  # letter_opener_web is auto-required by Bundler via the :staging group.
  config.action_mailer.delivery_method = :letter_opener_web

  # Upload to the dev R2 bucket so staging review apps don't touch production
  # assets (see config/storage.yml).
  config.active_storage.service = :cloudflare_dev
end
