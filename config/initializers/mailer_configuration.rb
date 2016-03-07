unless Rails.env.test?
  ActionMailer::Base.smtp_settings = {
    port:           ENV['SPARKPOST_PORT'],
    address:        'smtp.sparkpostmail.com',
    user_name:      ENV['SPARKPOST_USERNAME'],
    password:       ENV['SPARKPOST_PASSWORD'],
    authentication: :plain
  }
end