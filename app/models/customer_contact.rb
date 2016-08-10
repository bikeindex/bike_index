class CustomerContact < ActiveRecord::Base
  def self.old_attr_accessible
    %w(title body user_id user_email creator_email creator_id contact_type bike_id info_hash).map(&:to_sym).freeze
  end

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
    user = User.fuzzy_email_find(user_email)
    user ||= User.fuzzy_unconfirmed_primary_email_find(user_email)
    self.user = user if user
    true
  end

end
