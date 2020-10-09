class UserPhoneMigrateWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: false

  def perform(user_id, phone_number = nil)
    user = User.find_by_id(user_id)
    phone_number ||= user&.phone
    return unless user.present? && phone_number.present?
    user.user_phones.create(phone: phone_number, confirmation_code: "legacy_migration")
  end
end
