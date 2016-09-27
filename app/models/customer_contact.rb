class CustomerContact < ActiveRecord::Base
  validates_presence_of :title
  validates_presence_of :body
  validates_presence_of :contact_type
  # validates_presence_of :creator_id
  validates_presence_of :bike_id
  validates_presence_of :creator_email
  validates_presence_of :user_email
  serialize :info_hash


  belongs_to :bike
  belongs_to :user
  belongs_to :creator, class_name: 'User'

  before_save :normalize_email_and_find_user
  def normalize_email_and_find_user
    self.user_email = EmailNormalizer.normalize(user_email)
    self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(user_email)
    true
  end

end
