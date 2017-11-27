class User < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  cattr_accessor :current_user

  has_secure_password

  def self.old_attr_accessible
    # :email, # Also maybe a all_emails field for searching.. 
    %w(name username email password password_confirmation current_password terms_of_service
       vendor_terms_of_service when_vendor_terms_of_service phone zipcode title my_bikes_hash
       avatar avatar_cache description twitter show_twitter website show_website show_bikes
       show_phone has_stolen_bikes can_send_many_stolen_notifications my_bikes_link_target
       my_bikes_link_title is_emailable additional_emails).map(&:to_sym).freeze
 end

  attr_accessor :my_bikes_link_target, :my_bikes_link_title, :current_password
  # stripe_id, is_paid_member, paid_membership_info

  mount_uploader :avatar, AvatarUploader

  has_many :payments
  has_many :subscriptions, -> { subscription }, class_name: 'Payment'
  has_many :memberships, dependent: :destroy
  has_many :organization_embeds, class_name: 'Organization', foreign_key: :auto_user_id
  has_many :organizations, through: :memberships
  has_many :ownerships, dependent: :destroy
  has_many :current_ownerships, -> { current }, class_name: 'Ownership'
  has_many :owned_bikes, through: :ownerships, source: :bike
  has_many :currently_owned_bikes, through: :current_ownerships, source: :bike
  has_many :oauth_applications, class_name: 'Doorkeeper::Application', as: :owner

  has_many :integrations, dependent: :destroy
  has_many :creation_states, inverse_of: :creator, foreign_key: :creator_id
  has_many :created_ownerships, class_name: 'Ownership', inverse_of: :creator, foreign_key: :creator_id
  has_many :created_bikes, class_name: 'Bike', inverse_of: :creator, foreign_key: :creator_id
  has_many :locks, dependent: :destroy
  has_many :user_emails, dependent: :destroy

  has_many :sent_stolen_notifications, class_name: 'StolenNotification', foreign_key: :sender_id
  has_many :received_stolen_notifications, class_name: 'StolenNotification', foreign_key: :receiver_id

  has_many :organization_invitations, class_name: 'OrganizationInvitation', inverse_of: :inviter
  has_many :organization_invitations, class_name: 'OrganizationInvitation', inverse_of: :invitee

  before_create :generate_username_confirmation_and_auth
  after_create :perform_create_jobs
  serialize :paid_membership_info
  serialize :my_bikes_hash
  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }

  validates_uniqueness_of :username, case_sensitive: false
  def to_param
    username
  end

  validates :password,
    presence: true,
    length: { within: 6..100 },
    on: :create
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: 'must contain at least one letter', on: :create

  validates :password, 
    confirmation: true,
    length: { within: 6..100 },
    allow_blank: true,
    on: :update
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: 'must contain at least one letter', on: :update, allow_blank: true

  validates_presence_of :email
  validates_uniqueness_of :email, case_sensitive: false

  class << self
    def fuzzy_email_find(email)
      UserEmail.confirmed.fuzzy_user_find(email)
    end

    def fuzzy_unconfirmed_primary_email_find(email)
      find_by_email(EmailNormalizer.normalize(email))
    end

    def fuzzy_confirmed_or_unconfirmed_email_find(email)
      fuzzy_email_find(email) || fuzzy_unconfirmed_primary_email_find(email)
    end

    def friendly_id_find(n)
      u = self.fuzzy_email_find(n)
      u && u.id
    end

    def admin_text_search(n)
      search_str = "%#{n.strip}%"
      (where("name ILIKE ? OR email ILIKE ?", search_str, search_str) +
        joins(:user_emails).where("user_emails.email ILIKE ?", search_str)).uniq
    end
  end

  def additional_emails=(value)
    UserEmail.add_emails_for_user_id(id, value)
  end

  def secondary_emails
    user_emails.where.not(email: email).pluck(:email)
  end

  validate :ensure_unique_email
  def ensure_unique_email
    return true unless self.class.fuzzy_confirmed_or_unconfirmed_email_find(email)
    return true if id.present? # Because existing users shouldn't see this error
    errors.add(:email, 'That email is already signed up on Bike Index.')
  end

  def perform_create_jobs
    CreateUserJobs.new(self).perform_create_jobs
  end

  def superuser?
    superuser
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
      CreateUserJobs.new(self).perform_confirmed_jobs
      true
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

  def role(organization)
    m = Membership.where(user_id: id, organization_id: organization.id).first
    m && m.role
  end

  def is_member_of?(organization)
    return false unless organization.present?
    Membership.where(user_id: id, organization_id: organization.id).present? || superuser?
  end

  def is_admin_of?(organization)
    return false unless organization.present?
    Membership.where(user_id: id, organization_id: organization.id, role: 'admin').present? || superuser?
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
    Bike.unscoped.where(id: bike_ids(user_hidden))
  end

  def rough_approx_bikes # Rough fix for users with large numbers of bikes
    Bike.includes(:ownerships).where(ownerships: { current: true, user_id: id })
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
      self.website = Urlifyer.urlify(website)
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
    self.email = EmailNormalizer.normalize(email)
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
    if !confirmed
      self.confirmation_token = (Digest::MD5.hexdigest "#{SecureRandom.hex(10)}-#{DateTime.now.to_s}")
    end
    generate_auth_token
    true
  end
end
