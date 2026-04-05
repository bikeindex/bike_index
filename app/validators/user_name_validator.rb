class UserNameValidator < ActiveModel::Validator
  def self.valid?(str)
    OrganizationNameValidator.valid?(str)
  end

  def validate(record)
    return true if record.username.blank?
    return true if self.class.valid?(record.username)

    record.errors.add(:username, "is reserved")
  end
end
