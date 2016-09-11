class IntegrationAssociationError < StandardError
end

class Integration < ActiveRecord::Base
  def self.old_attr_accessible
    %w(access_token provider_name user_id user information).map(&:to_sym).freeze
  end

  validates_presence_of :access_token
  validates_presence_of :information

  serialize :information, JSON

  belongs_to :user

  before_create :associate_with_user
  def associate_with_user
    self.provider_name ||= information['provider']
    if provider_name == 'facebook' || provider_name == 'strava'
      update_or_create_user(email: information['info']['email'], name: information['info']['name'])
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
    pword = SecureRandom.hex
    i_user = User.new(email: email, name: name, password: pword, password_confirmation: pword)
    if i_user.save
      i_user.confirm(i_user.confirmation_token)
    else
      raise IntegrationAssociationError, "#{provider_name} Integration fail: #{i_user.errors.full_messages}"
    end
    i_user
  end
end
