class User < ApplicationRecord
  include Phonifyerable
  include ActionView::Helpers::SanitizeHelper
  include FeatureFlaggable
  include Geocodeable

  cattr_accessor :current_user

  has_secure_password

  attr_accessor :my_bikes_link_target, :my_bikes_link_title, :current_password
  # stripe_id, is_paid_member, paid_membership_info

  mount_uploader :avatar, AvatarUploader

  has_many :ambassador_task_assignments
  has_many :ambassador_tasks, through: :ambassador_task_assignments
  has_many :payments
  has_many :subscriptions, -> { subscription }, class_name: "Payment"
  has_many :memberships, dependent: :destroy
  has_many :sent_memberships, class_name: "Membership", foreign_key: :sender_id
  has_many :organization_embeds, class_name: "Organization", foreign_key: :auto_user_id
  has_many :organizations, through: :memberships
  has_many :ownerships, dependent: :destroy
  has_many :current_ownerships, -> { current }, class_name: "Ownership"
  has_many :owned_bikes, through: :ownerships, source: :bike
  has_many :currently_owned_bikes, through: :current_ownerships, source: :bike
  has_many :oauth_applications, class_name: "Doorkeeper::Application", as: :owner

  has_many :integrations, dependent: :destroy
  has_many :creation_states, inverse_of: :creator, foreign_key: :creator_id
  has_many :created_ownerships, class_name: "Ownership", inverse_of: :creator, foreign_key: :creator_id
  has_many :created_bikes, class_name: "Bike", inverse_of: :creator, foreign_key: :creator_id
  has_many :locks, dependent: :destroy
  has_many :user_emails, dependent: :destroy

  has_many :sent_stolen_notifications, class_name: "StolenNotification", foreign_key: :sender_id
  has_many :received_stolen_notifications, class_name: "StolenNotification", foreign_key: :receiver_id
  has_many :theft_alerts

  belongs_to :state
  belongs_to :country

  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :superusers, -> { where(superuser: true) }
  scope :ambassadors, -> { where(id: Membership.ambassador_organizations.select(:user_id)) }

  validates_uniqueness_of :username, case_sensitive: false

  validates :password,
    presence: true,
    length: { within: 6..100 },
    on: :create
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: "must contain at least one letter", on: :create

  validates :password,
    confirmation: true,
    length: { within: 6..100 },
    allow_blank: true,
    on: :update
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: "must contain at least one letter", on: :update, allow_blank: true

  validate :preferred_language_is_an_available_locale

  validates_presence_of :email
  validates_uniqueness_of :email, case_sensitive: false

  before_validation :set_calculated_attributes
  before_validation :set_address
  validate :ensure_unique_email
  before_create :generate_username_confirmation_and_auth
  after_commit :perform_create_jobs, on: :create, unless: lambda { self.skip_create_jobs }

  attr_accessor :skip_create_jobs

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

    def username_friendly_find(n)
      if n.is_a?(Integer) || n.match(/\A\d*\z/).present?
        where(id: n).first
      else
        find_by_username(n)
      end
    end

    def friendly_find(str)
      self.fuzzy_email_find(str) || username_friendly_find(str)
    end

    def friendly_id_find(str)
      friendly_find(str)&.id
    end

    def admin_text_search(str)
      q = "%#{str.to_s.strip}%"
      unscoped.includes(:user_emails)
        .where("users.name ILIKE ? OR users.email ILIKE ? OR user_emails.email ILIKE ?", q, q, q)
        .distinct.references(:user_emails)
    end

    def from_auth(auth)
      return nil unless auth&.kind_of?(Array)
      where(id: auth[0], auth_token: auth[1]).first
    end
  end

  def additional_emails=(value)
    UserEmail.add_emails_for_user_id(id, value)
  end

  def secondary_emails
    user_emails.where.not(email: email).pluck(:email)
  end

  def ensure_unique_email
    return true unless self.class.fuzzy_confirmed_or_unconfirmed_email_find(email)
    return true if id.present? # Because existing users shouldn't see this error
    errors.add(:email, :email_already_exists)
  end

  def confirmed?; confirmed end

  def unconfirmed?; !confirmed? end

  def perform_create_jobs
    AfterUserCreateWorker.new.perform(id, "new", user: self)
  end

  def superuser?; superuser end

  def developer?; developer end

  def ambassador?
    memberships.ambassador_organizations.any?
  end

  def to_param; username end

  def display_name; name.present? ? name : email end

  def donations; payments.sum(:amount_cents) end

  def donor?; donations > 900 end

  def paid_org?; organizations.paid.any? end

  def can_impound?; superuser? || organizations.any? { |o| o.enabled?("impound_bikes") } end

  def authorized?(obj)
    return true if superuser?
    return obj.authorized?(self) if obj.is_a?(Bike)
    return member_of?(obj) if obj.is_a?(Organization)
    return obj.authorized?(self) if obj.is_a?(BikeSticker)
    false
  end

  def send_unstolen_notifications?
    superuser || organizations.any? { |o| o.enabled?("unstolen_notifications") }
  end

  def auth_token_time(auth_token_type)
    SecurityTokenizer.token_time(self[auth_token_type])
  end

  def auth_token_expired?(auth_token_type)
    auth_token_time(auth_token_type) < (Time.current - 1.hours)
  end

  def accepted_vendor_terms_of_service?
    vendor_terms_of_service
  end

  def accepted_vendor_terms_of_service=(val)
    if ParamsNormalizer.boolean(val)
      self.vendor_terms_of_service = true
      self.when_vendor_terms_of_service = Time.current
    end
    true
  end

  def send_password_reset_email
    unless auth_token_time("password_reset_token") > Time.current - 2.minutes
      update_auth_token("password_reset_token")
      EmailResetPasswordWorker.perform_async(id)
    end
  end

  def send_magic_link_email
    unless auth_token_time("magic_link_token") > Time.current - 1.minutes
      update_auth_token("magic_link_token")
      EmailMagicLoginLinkWorker.perform_async(id)
    end
  end

  def update_last_login(ip_address)
    save! unless id.present? # throw an error that shows why the user isn't created
    update_columns(last_login_at: Time.current, last_login_ip: ip_address)
  end

  def confirm(token)
    if token == confirmation_token
      self.confirmation_token = nil
      self.confirmed = true
      self.save
      AfterUserCreateWorker.new.perform(id, "confirmed", user: self)
      true
    end
  end

  def role(organization)
    m = Membership.where(user_id: id, organization_id: organization.id).first
    m && m.role
  end

  def member_of?(organization)
    return false unless organization.present?
    Membership.claimed.where(user_id: id, organization_id: organization.id).present? || superuser?
  end

  def admin_of?(organization)
    return false unless organization.present?
    Membership.claimed.where(user_id: id, organization_id: organization.id, role: "admin").present? || superuser?
  end

  def has_membership?
    memberships.any?
  end

  def has_police_membership?
    organizations.law_enforcement.any?
  end

  def has_shop_membership?
    organizations.bike_shop.any?
  end

  def default_organization
    return @default_organization if defined?(@default_organization) # Memoize, permit nil
    @default_organization = organizations&.first # Maybe at some point use memberships to get the most recent, for now, speed
  end

  def partner_sign_up
    partner_data && partner_data["sign_up"].present? ? partner_data["sign_up"] : nil
  end

  def bikes(user_hidden = true)
    Bike.unscoped
      .includes(:tertiary_frame_color, :secondary_frame_color, :primary_frame_color, :current_stolen_record)
      .where(id: bike_ids(user_hidden)).reorder(:created_at)
  end

  def rough_approx_bikes # Rough fix for users with large numbers of bikes
    Bike.includes(:ownerships).where(ownerships: { current: true, user_id: id }).reorder(:created_at)
  end

  def bike_ids(user_hidden = true)
    ows = ownerships.includes(:bike).where(example: false, current: true)
    if user_hidden
      ows = ows.map { |o| o.bike_id if o.user_hidden || o.bike }
    else
      ows = ows.map { |o| o.bike_id if o.bike }
    end
    ows.reject(&:blank?)
  end

  # Just check a couple, to avoid blocking save
  def stolen_bikes_without_locations
    @stolen_bikes_without_locations ||= rough_approx_bikes.limit(10).select { |b| b.current_stolen_record&.missing_location? }
  end

  def render_donation_request
    return nil unless has_police_membership? && !organizations.law_enforcement.paid.any?
    "law_enforcement"
  end

  def set_calculated_attributes
    self.phone = Phonifyer.phonify(phone) if phone
    self.username = Slugifyer.slugify(username) if username
    self.email = EmailNormalizer.normalize(email)
    self.title = strip_tags(title) if title.present?
    self.website = Urlifyer.urlify(website) if website.present?
    if my_bikes_link_target.present? || my_bikes_link_title.present?
      mbh = my_bikes_hash || {}
      mbh["link_target"] = Urlifyer.urlify(my_bikes_link_target) if my_bikes_link_target.present?
      mbh["link_title"] = my_bikes_link_title if my_bikes_link_title.present?
      self.my_bikes_hash = mbh
    end
    unless skip_create_jobs || skip_geocoding # Don't run if we're resaving user
      self.has_stolen_bikes_without_locations = calculated_has_stolen_bikes_without_locations
    end
    true
  end

  def set_address
    self.address = [
      street,
      city,
      state&.abbreviation,
      zipcode,
      country&.iso,
    ].reject(&:blank?).join(", ")
  end

  def mb_link_target
    my_bikes_hash && my_bikes_hash["link_target"]
  end

  def mb_link_title
    (my_bikes_hash && my_bikes_hash["link_title"]) || mb_link_target
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

  def address_hash
    return if address.blank?
    {
      address: street,
      city: city,
      state: (state&.abbreviation),
      zipcode: zipcode,
      country: country&.iso,
    }.as_json
  end

  def update_auth_token(auth_token_type, time = nil)
    generate_auth_token(auth_token_type, time)
    save
  end

  def generate_auth_token(auth_token_type, time = nil)
    self.attributes = { auth_token_type => SecurityTokenizer.new_token(time) }
  end

  def access_tokens_for_application(i)
    Doorkeeper::AccessToken.where(resource_owner_id: id, application_id: i)
  end

  protected

  def calculated_has_stolen_bikes_without_locations
    return false if superuser
    return false if memberships.admin.any?
    stolen_bikes_without_locations.any?
  end

  def generate_username_confirmation_and_auth
    usrname = username || SecureRandom.urlsafe_base64
    while User.where(username: usrname).where.not(id: id).exists?
      usrname = SecureRandom.urlsafe_base64
    end
    self.username = usrname
    self.generate_auth_token("confirmation_token") if !confirmed
    generate_auth_token("auth_token")
    true
  end

  private

  def preferred_language_is_an_available_locale
    return if preferred_language.blank?
    return if I18n.available_locales.include?(preferred_language.to_sym)
    errors.add(:preferred_language, :not_an_available_language)
  end
end
