class BikeTokenInvitation < ActiveRecord::Base
  attr_accessible :message,
    :subject,
    :inviter_id,
    :bike_token_count,
    :organization_id,
    :invitee_id,
    :invitee_name,
    :invitee_email
  
  belongs_to :inviter, class_name: 'User', foreign_key: :inviter_id
  belongs_to :invitee, class_name: 'User', foreign_key: :invitee_id
  belongs_to :organization

  validates_presence_of :inviter, :invitee_email, :message, :subject, :bike_token_count, :organization_id

  after_create :if_user_exists_assign
  def if_user_exists_assign
    user = User.fuzzy_email_find(self.invitee_email)
    if user 
      self.assign_to(user)
    end
  end

  before_save :normalize_email 
  def normalize_email
    self.invitee_email.downcase.strip!
  end

  def assign_to(user)
    unless self.redeemed
      self.invitee_id = user.id
      bike_token_count.times do 
        BikeToken.create(user: user, organization: self.organization)
      end
      self.redeemed = true
      self.save!
      if self.invitee_name
        unless user.name.present?
          user.name = self.invitee_name
          user.save
        end
      end
    end
  end

end
