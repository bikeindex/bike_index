class User < ActiveRecord::Base
  cattr_accessor :current_user

  has_secure_password

  attr_accessible :name,
    :username,
    :email,
    :password,
    :password_confirmation,
    :terms_of_service,
    :vendor_terms_of_service,
    :when_vendor_terms_of_service,
    :phone,
    :zipcode,
    :title,
    :avatar,
    :avatar_cache,
    :description,
    :twitter,
    :show_twitter,
    :website,
    :show_website,
    :show_bikes,
    :show_phone,
    :has_stolen_bikes,
    :can_send_many_stolen_notifications

  mount_uploader :avatar, AvatarUploader

  has_many :memberships, dependent: :destroy
  has_many :organization_embeds, class_name: 'Organization', foreign_key: :auto_user_id
  has_many :organizations, through: :memberships
  has_many :ownerships, dependent: :destroy
  has_many :current_ownerships, class_name: 'Ownership', foreign_key: :user_id, conditions: {current: true}
  has_many :owned_bikes, through: :ownerships, source: :bike
  has_many :currently_owned_bikes, through: :current_ownerships, source: :bike
  has_many :oauth_applications, class_name: 'Doorkeeper::Application', as: :owner

  has_many :integrations, dependent: :destroy
  has_many :created_ownerships, class_name: 'Ownership', inverse_of: :creator
  has_many :created_bicycles, class_name: 'Bike', inverse_of: :creator
  has_many :bike_tokens, dependent: :destroy
  has_many :locks, dependent: :destroy

  has_many :sent_stolen_notifications, class_name: 'StolenNotification', foreign_key: :sender_id
  has_many :received_stolen_notifications, class_name: 'StolenNotification', foreign_key: :receiver_id

  has_many :organization_invitations, class_name: 'OrganizationInvitation', inverse_of: :inviter
  has_many :organization_invitations, class_name: 'OrganizationInvitation', inverse_of: :invitee

  before_create :generate_username_confirmation_and_auth

  validates_uniqueness_of :username, case_sensitive: false
  def to_param
    username
  end

  validates :password, 
    presence: true, 
    length: {within: 6..100},
    on: :create
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: 'must contain at least one letter', on: :create

  validates :password, 
    confirmation: true, 
    length: {within: 6..100},
    allow_blank: true,
    on: :update
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: 'must contain at least one letter', on: :update, allow_blank: true

  validates_presence_of :email
  validates_uniqueness_of :email, case_sensitive: false


  include PgSearch

  pg_search_scope :admin_search, against: {
    name: 'A',
    email: 'A'
    },
    using: {tsearch: {dictionary: "english", prefix: true}}

  def self.admin_text_search(query)
    if query.present?
      admin_search(query)
    else
      scoped
    end
  end

  def superuser?
    self.superuser
  end

  def set_password_reset_token
    self.password_reset_token = (Digest::MD5.hexdigest "#{SecureRandom.hex(10)}-#{DateTime.now.to_s}")
    self.save
  end

  def accept_vendor_terms_of_service
    self.vendor_terms_of_service = true
    self.when_vendor_terms_of_service = DateTime.now
    self.save
  end

  def send_password_reset_email
    self.set_password_reset_token
    EmailResetPasswordWorker.perform_async(self.id)
  end

  def confirm(token)
    if token == confirmation_token
      self.confirmation_token = nil
      self.confirmed = true
      self.save
    end
  end
  
  # We have a different authentication flow than has_secure_password because of email confirmation
  # and banning
  def signin(password)
    if self.confirmed
      self.authenticate(password)
    else
      return false
    end
  end
  
  def self.fuzzy_email_find(email)
    if !email.blank?
      self.find(:first, conditions: [ "lower(email) = ?", email.downcase ])
    else
      nil
    end
  end

  def role(organization)
    m = Membership.where(user_id: self.id, organization_id: organization.id).first
    if m.present?
      return m.role
    end
  end

  def is_member_of?(organization)
    if organization.present?
      m = Membership.where(user_id: self.id, organization_id: organization.id)
      m.present?
    end
  end

  def is_admin_of?(organization)
    m = Membership.where(user_id: self.id, organization_id: organization.id).first
    m.role == "admin"
  end
  
  def has_membership?
    self.memberships.any?
  end

  def has_police_membership?
    self.organizations.police.any?
  end

  def has_shop_membership?
    self.organizations.shop.any?
  end

  def bikes
    ownerships = Ownership.where(user_id: self.id)
      .where(example: false).where(current: true).pluck(:bike_id)
  end

  def current_organization
    if self.has_membership?
      self.memberships.current_membership
    end
  end

  def has_stolen?
    stolen = false
    self.bikes.each do |bike_id|
      stolen = true if Bike.find(bike_id).stolen
    end
    return stolen
  end

  def available_bike_tokens
    self.bike_tokens.available
  end

  before_save :set_urls
  def set_urls
    if self.website
      self.website = Urlifyer.urlify(self.website)
    end
  end

  before_save :set_phone
  def set_phone
    self.phone = Phonifyer.phonify(self.phone) if self.phone 
  end

  before_save :slug_username
  def slug_username
    self.username = Slugifyer.slugify(self.username) if self.username
  end

  def generate_auth_token
    begin
      self.auth_token = SecureRandom.urlsafe_base64 + "t#{Time.now.to_i}"
    end while User.where(auth_token: auth_token).exists?
  end

  protected

  def generate_username_confirmation_and_auth
    begin
      username = SecureRandom.urlsafe_base64
    end while User.where(username: username).exists?
    self.username = username
    if !self.confirmed
      self.confirmation_token = (Digest::MD5.hexdigest "#{SecureRandom.hex(10)}-#{DateTime.now.to_s}")
    end
    generate_auth_token
    true
  end

end
