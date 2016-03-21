class User < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  cattr_accessor :current_user

  has_secure_password

  attr_accessible :name,
    :username,
    :email,
    :password,
    :password_confirmation,
    :current_password,
    :terms_of_service,
    :vendor_terms_of_service,
    :when_vendor_terms_of_service,
    :phone,
    :zipcode,
    :title,
    :my_bikes_hash,
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
    :can_send_many_stolen_notifications,
    :my_bikes_link_target,
    :my_bikes_link_title,
    :is_emailable


  attr_accessor :my_bikes_link_target, :my_bikes_link_title, :current_password
  # stripe_id, is_paid_member, paid_membership_info

  mount_uploader :avatar, AvatarUploader

  has_many :payments
  has_many :subscriptions, class_name: "Payment", conditions: Proc.new { payments.where(is_recurring: true) }
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
  has_many :locks, dependent: :destroy

  has_many :sent_stolen_notifications, class_name: 'StolenNotification', foreign_key: :sender_id
  has_many :received_stolen_notifications, class_name: 'StolenNotification', foreign_key: :receiver_id

  has_many :organization_invitations, class_name: 'OrganizationInvitation', inverse_of: :inviter
  has_many :organization_invitations, class_name: 'OrganizationInvitation', inverse_of: :invitee

  before_create :generate_username_confirmation_and_auth
  serialize :paid_membership_info
  serialize :my_bikes_hash

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
    superuser
  end

  def developer?
    developer
  end

  def content?
    is_content_admin
  end

  def display_name
    name || email
  end

  def admin_authorized(type)
    return true if superuser
    return case type
    when 'content'
      true if is_content_admin
    when 'any'
      true if is_content_admin
    end
    false
  end

  def reset_token_time
    t = password_reset_token && password_reset_token.split('-')[0]
    t = (t.present? && t.to_i > 1427848192) ? t.to_i : 1364777722
    Time.at(t)
  end

  def set_password_reset_token(t=Time.now.to_i)
    self.password_reset_token = "#{t}-" + Digest::MD5.hexdigest("#{SecureRandom.hex(10)}-#{DateTime.now}")
    self.save
  end

  def accept_vendor_terms_of_service
    self.vendor_terms_of_service = true
    self.when_vendor_terms_of_service = DateTime.now
    save
  end

  def send_password_reset_email
    unless reset_token_time > Time.now - 2.minutes
      set_password_reset_token
      EmailResetPasswordWorker.perform_async(id)
    end
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
      self.find(:first, conditions: [ "lower(email) = ?", email.downcase.strip ])
    else
      nil
    end
  end

  def self.fuzzy_id(n)
    u = self.fuzzy_email_find(n)
    return u.id if u.present?
  end

  def role(organization)
    m = Membership.where(user_id: id, organization_id: organization.id).first
    if m.present?
      return m.role
    end
  end

  def is_member_of?(organization)
    if organization.present?
      m = Membership.where(user_id: id, organization_id: organization.id)
      m.present?
    end
  end

  def is_admin_of?(organization)
    m = Membership.where(user_id: id, organization_id: organization.id).first
    m.present? && m.role == "admin"
  end
  
  def has_membership?
    memberships.any?
  end

  def has_police_membership?
    organizations.police.any?
  end

  def has_shop_membership?
    organizations.shop.any?
  end

  def bikes(user_hidden=true)
    Bike.unscoped.find(bike_ids(user_hidden))
  end

  def bike_ids(user_hidden=true)
    ows = ownerships.where(example: false).where(current: true)
    if user_hidden
      ows = ows.map{ |o| o.bike_id if o.user_hidden || o.bike }
    else
      ows = ows.map{ |o| o.bike_id if o.bike }
    end
    ows.reject(&:blank?)
  end

  def current_subscription
    subscriptions.current.first
  end

  def delay_subscription_request
    update_attribute :make_subscription_request, false
    MarkForSubscriptionRequestWorker.perform_in(1.days, id)
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

  before_save :set_urls
  def set_urls
    self.title = strip_tags(title) if title.present?
    if website
      self.website = Urlifyer.urlify(self.website)
    end
    mbh = my_bikes_hash || {}
    mbh[:link_target] = Urlifyer.urlify(my_bikes_link_target) if my_bikes_link_target.present?
    mbh[:link_title] = my_bikes_link_title if my_bikes_link_title.present?
    self.my_bikes_hash = mbh
    true
  end

  def mb_link_target
    my_bikes_hash && my_bikes_hash[:link_target]
  end

  def mb_link_title
    (my_bikes_hash && my_bikes_hash[:link_title]) || mb_link_target
  end

  before_validation :normalize_attributes
  def normalize_attributes
    self.phone = Phonifyer.phonify(phone) if phone 
    self.username = Slugifyer.slugify(username) if username
    self.email = EmailNormalizer.new(email).normalized
  end

  def userlink
    if show_bikes
      "/users/#{username}" 
    elsif twitter.present?
      "https://twitter.com/#{twitter}"
    else
      ""
    end
  end

  def generate_auth_token
    begin
      self.auth_token = SecureRandom.urlsafe_base64 + "t#{Time.now.to_i}"
    end while User.where(auth_token: auth_token).exists?
  end

  def access_tokens_for_application(i)
    Doorkeeper::AccessToken.where(resource_owner_id: id, application_id: i)
  end

  protected

  def self.from_auth(auth)
    return nil unless auth && auth.kind_of?(Array)
    self.where(id: auth[0], auth_token: auth[1]).first
  end

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
