ActiveSupport::Notifications.subscribe('grape_key') do |name, starts, ends, notification_id, payload|
  t = payload.delete(:time)
  Rails.logger.info payload.except(:response)
                           .merge(duration: t[:total], db: t[:db], view: t[:view])
                           .to_json
end