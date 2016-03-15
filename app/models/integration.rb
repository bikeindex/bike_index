class IntegrationAssociationError < StandardError
end

class Integration < ActiveRecord::Base
  attr_accessible :access_token,
                  :provider_name,
                  :user_id,
                  :user,
                  :information

  validates_presence_of :access_token
  validates_presence_of :information

  serialize :information, JSON

  belongs_to :user

  before_create :associate_with_user
  def associate_with_user
    self.provider_name ||= information['provider']
    if provider_name == 'facebook'
      update_or_create_user(email: information['info']['email'], name: information['info']['name'])
    elsif provider_name == 'strava'
      update_or_create_user(email: information['info']['email'], name: information['info']['name'])
    end
  end

  def update_or_create_user(email:, name:)
    i_user = User.fuzzy_email_find(email)
    if i_user.present?
      Integration.where(user_id: i_user.id).map(&:destroy)
      i_user.update_attribute :name, name unless i_user.name.present?
      i_user.update_attribute :confirmed, true unless i_user.confirmed?
    else
      i_user = create_user(email: email, name: name)
    end
    self.user = i_user
  end

  def create_user(email:, name:)
    pword = SecureRandom.hex
    i_user = User.new(email: email, name: name, password: pword, password_confirmation: pword)
    i_user.confirmed = true
    if i_user.save
      CreateUserJobs.new(user: i_user).do_jobs
    else
      raise IntegrationAssociationError, 'Oh shit something in sign on integration broke'
    end
    i_user
  end
end
