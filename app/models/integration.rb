class IntegrationAssociationError < StandardError
end

class Integration < ApplicationRecord
  validates_presence_of :access_token
  validates_presence_of :information

  serialize :information, JSON

  belongs_to :user

  before_create :associate_with_user

  def self.email_from_globalid_pii(auth_hash)
    decrypted_pii = auth_hash.dig("info", "decrypted_pii")&.first
    decrypted_pii && decrypted_pii["value"]
  end

  def associate_with_user
    self.provider_name ||= information["provider"]
    if provider_name == "facebook" || provider_name == "strava"
      update_or_create_user(email: information["info"]["email"], name: information["info"]["name"])
    elsif provider_name == "globalid"
      update_or_create_user(email: self.class.email_from_globalid_pii(information),
                            name: information["info"]["name"])
    end
  end

  def update_or_create_user(email:, name:)
    i_user = User.fuzzy_confirmed_or_unconfirmed_email_find(email)
    if i_user.present?
      Integration.where(user_id: i_user.id).map(&:destroy)
      i_user.update_attribute :name, name unless i_user.name.present?
      i_user.confirm(i_user.confirmation_token) if i_user.confirmation_token
    else
      i_user = create_user(email: email, name: name)
    end
    self.user = i_user
  end

  def create_user(email:, name:)
    password = SecurityTokenizer.new_password_token
    i_user = User.new(email: email,
                      name: name,
                      password: password,
                      password_confirmation: password)
    if i_user.save!
      i_user.confirm(i_user.confirmation_token)
    else
      errors.add :user_errors, i_user.errors
    end
    i_user
  end
end
