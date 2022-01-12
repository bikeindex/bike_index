unless Rails.env.test?
  if ENV["SPARKPOST_ENABLED"].present?
    ActionMailer::Base.smtp_settings = {
      port: ENV["SPARKPOST_PORT"],
      address: "smtp.sparkpostmail.com",
      user_name: ENV["SPARKPOST_USERNAME"],
      password: ENV["SPARKPOST_PASSWORD"],
      authentication: :plain
    }
  else
    config.action_mailer.delivery_method = :postmark

    config.action_mailer.postmark_settings = {
      api_token: ENV["POSTMARK_API_TOKEN"]
    }
  end
end
