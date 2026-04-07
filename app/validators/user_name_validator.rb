class UserNameValidator < ActiveModel::Validator
  # Collection routes under /users/ that would conflict with usernames
  INVALID_USERNAMES = %w[new confirm please_confirm_email resend_confirmation_email
    request_password_reset_form send_password_reset_email
    update_password_form_with_reset_token update_password_with_reset_token].freeze

  def self.valid?(str)
    return false if str.blank?
    slugged = Slugifyer.slugify(str).tr("-", "_")
    return false if slugged.length < 2
    return false if INVALID_USERNAMES.include?(slugged)
    !BadWordCleaner::BAD_WORDS.include?(slugged)
  end

  def validate(record)
    return true if record.username.blank?
    return true if self.class.valid?(record.username)

    record.errors.add(:username, "is reserved")
  end
end
