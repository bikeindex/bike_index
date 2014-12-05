Bikeindex::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb
  Rails.application.routes.default_url_options[:host] = ENV['BASE_URL']
  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :dalli_store,
    { namespace: Bikeindex, expires_in: 0, compress: true }
  config.action_controller.page_cache_directory = Rails.public_path + "/caches/"

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true
  ActionMailer::Base.smtp_settings = {
      port:           ENV['MANDRILL_PORT'],
      address:        'smtp.mandrillapp.com',
      user_name:      ENV['MANDRILL_USERNAME'],
      password:       ENV['MANDRILL_PASSWORD'],
      authentication: :plain
  }
  ActionMailer::Base.delivery_method = :smtp

  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger.const_get( ENV['LOG_LEVEL'] ? ENV['LOG_LEVEL'].upcase : 'INFO' )

  # Make sure we reload the API after every request!
  @last_api_change = Time.now
  api_reloader = ActiveSupport::FileUpdateChecker.new(Dir["#{Rails.root}/app/controllers/api/v2/**/*.rb"]) do |reloader|
    times = Dir["#{Rails.root}/app/api/**/*.rb"].map{|f| File.mtime(f) }
    files = Dir["#{Rails.root}/app/api/**/*.rb"].map{|f| f }

    Rails.logger.debug "! Change detected: reloading following files:"
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
