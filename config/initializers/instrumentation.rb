unless Rails.env.test?
  ActiveSupport::Notifications.subscribe('grape_key') do |name, starts, ends, notification_id, payload|
    time = payload.delete(:time)
    Rails.logger.info payload.except(:response)
                             .merge(time.merge(duration: time.delete(:total)))
                             .to_json
  end
end