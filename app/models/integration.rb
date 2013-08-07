class IntegrationAssociationError < StandardError
end

class Integration < ActiveRecord::Base
  attr_accessible :access_token, 
    :provider_name,
    :user_id,
    :user,
    :information

  serialize :information, JSON

  validates_presence_of :access_token, :provider_name, :information

  belongs_to :user

  # http://graph.facebook.com/64901670/picture?type=square => ?type=large gets a bigger image

  before_create :associate_with_user 
  def associate_with_user
    if self.provider_name == "facebook"
      i_email = self.information['info']['email']
      i_name = self.information['info']['name']
      i_user = User.fuzzy_email_find(i_email)
      if i_user.present?
        if Integration.where(user_id: i_user.id).any?
          Integration.where(user_id: i_user.id).map(&:destroy)
        end
        unless i_user.name.present?
          i_user.name = i_name
          i_user.save
        end
        unless i_user.confirmed?
           i_user.confirmed = true 
           i_user.save
        end
      else
        pword = SecureRandom.hex
        i_user = User.new(email: i_email, name: i_name, password: pword, password_confirmation: pword)
        i_user.confirmed = true
        if i_user.save
          CreateUserJobs.new(user: i_user).do_jobs
        else
          raise IntegrationAssociationError, "Oh shit something broke"
        end
      end
      self.user = i_user
      self.user
    end
  end


end
