# == Schema Information
#
# Table name: users
#
#  id                                 :integer          not null, primary key
#  address_set_manually               :boolean          default(FALSE)
#  admin_options                      :jsonb
#  alert_slugs                        :jsonb
#  auth_token                         :string(255)
#  avatar                             :string(255)
#  banned                             :boolean          default(FALSE), not null
#  can_send_many_stolen_notifications :boolean          default(FALSE), not null
#  city                               :string
#  confirmation_token                 :string(255)
#  confirmed                          :boolean          default(FALSE), not null
#  deleted_at                         :datetime
#  description                        :text
#  developer                          :boolean          default(FALSE), not null
#  email                              :string(255)
#  instagram                          :string
#  last_login_at                      :datetime
#  last_login_ip                      :string
#  latitude                           :float
#  longitude                          :float
#  magic_link_token                   :text
#  my_bikes_hash                      :jsonb
#  name                               :string(255)
#  neighborhood                       :string
#  no_address                         :boolean          default(FALSE)
#  no_non_theft_notification          :boolean          default(FALSE)
#  notification_newsletters           :boolean          default(FALSE), not null
#  notification_unstolen              :boolean          default(TRUE)
#  partner_data                       :jsonb
#  password                           :text
#  password_digest                    :string(255)
#  phone                              :string(255)
#  preferred_language                 :string
#  show_bikes                         :boolean          default(FALSE), not null
#  show_instagram                     :boolean          default(FALSE)
#  show_phone                         :boolean          default(TRUE)
#  show_twitter                       :boolean          default(FALSE), not null
#  show_website                       :boolean          default(FALSE), not null
#  street                             :string
#  superuser                          :boolean          default(FALSE), not null
#  terms_of_service                   :boolean          default(FALSE), not null
#  time_single_format                 :boolean          default(FALSE)
#  title                              :text
#  token_for_password_reset           :text
#  twitter                            :string(255)
#  username                           :string(255)
#  vendor_terms_of_service            :boolean
#  when_vendor_terms_of_service       :datetime
#  zipcode                            :string(255)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  country_id                         :integer
#  state_id                           :integer
#  stripe_id                          :string(255)
#
# Indexes
#
#  index_users_on_auth_token                (auth_token)
#  index_users_on_token_for_password_reset  (token_for_password_reset)
#
class User < ApplicationRecord
  include ActionView::Helpers::SanitizeHelper
  include FeatureFlaggable
  include Geocodeable

  cattr_accessor :current_user

  acts_as_paranoid
  has_secure_password

  attr_accessor :my_bikes_link_target, :my_bikes_link_title, :current_password
  # stripe_id, is_paid_member, paid_organization_role_info

  mount_uploader :avatar, AvatarUploader

  has_many :ambassador_task_assignments
  has_many :ambassador_tasks, through: :ambassador_task_assignments
  has_many :payments
  has_many :notifications
  has_many :organization_roles
  has_many :sent_organization_roles, class_name: "OrganizationRole", foreign_key: :sender_id
  has_many :organization_embeds, class_name: "Organization", foreign_key: :auto_user_id
  has_many :organizations, through: :organization_roles
  has_many :memberships
  has_many :stripe_subscriptions
  has_many :ownerships
  has_many :bike_sticker_updates
  has_many :updated_bike_stickers, -> { distinct }, through: :bike_sticker_updates, class_name: "BikeSticker", source: :bike_sticker
  has_many :current_ownerships, -> { current }, class_name: "Ownership"
  has_many :owned_bikes, through: :ownerships, source: :bike
  has_many :oauth_applications, class_name: "Doorkeeper::Application", as: :owner
  has_many :user_registration_organizations
  has_many :uro_organizations, through: :user_registration_organizations, class_name: "Organization", source: :organization

  has_many :integrations, dependent: :destroy
  has_many :impound_claims
  has_many :impound_records
  has_many :created_ownerships, class_name: "Ownership", inverse_of: :creator, foreign_key: :creator_id
  has_many :created_bikes, class_name: "Bike", inverse_of: :creator, foreign_key: :creator_id
  has_many :locks, dependent: :destroy
  has_many :user_emails, dependent: :destroy
  has_many :user_phones
  has_many :user_alerts
  has_many :superuser_abilities

  has_many :sent_stolen_notifications, class_name: "StolenNotification", foreign_key: :sender_id
  has_many :received_stolen_notifications, class_name: "StolenNotification", foreign_key: :receiver_id
  has_many :theft_alerts
  has_many :feedbacks

  has_one :membership_active, -> { active }, class_name: "Membership"
  has_one :mailchimp_datum
  has_one :user_ban
  accepts_nested_attributes_for :user_ban

  scope :banned, -> { where(banned: true) }
  scope :confirmed, -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :superuser_abilities, -> { left_joins(:superuser_abilities).where.not(superuser_abilities: {id: nil}) }
  scope :ambassadors, -> { where(id: OrganizationRole.ambassador_organizations.select(:user_id)) }
  scope :partner_sign_up, -> { where("partner_data -> 'sign_up' IS NOT NULL") }
  scope :member, -> { includes(:memberships).merge(Membership.active) }

  validates_uniqueness_of :username, case_sensitive: false

  validates :password,
    presence: true,
    length: {within: 12..100},
    on: :create
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: "must contain at least one letter", on: :create

  validates :password,
    confirmation: true,
    length: {within: 12..100},
    allow_blank: true,
    on: :update
  validates_format_of :password, with: /\A.*(?=.*[a-z]).*\Z/i, message: "must contain at least one letter", on: :update, allow_blank: true

  validate :preferred_language_is_an_available_locale

  validates_presence_of :email
  validates_uniqueness_of :email, case_sensitive: false

  before_validation :set_calculated_attributes
  validate :ensure_unique_email
  before_create :generate_username_confirmation_and_auth
  after_commit :perform_create_jobs, on: :create, unless: lambda { skip_update }
  after_commit :perform_user_update_jobs

  attr_accessor :skip_update

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

    def username_friendly_find(str)
      if str.is_a?(Integer) || str.match(/\A\d+\z/).present?
        where(id: str).first
      else
        find_by_username(str)
      end
    end

    def friendly_find(str)
      fuzzy_email_find(str) || username_friendly_find(str)
    end

    def friendly_find_id(str)
      friendly_find(str)&.id
    end

    def admin_text_search(str)
      q = "%#{str.to_s.strip}%"
      unscoped.includes(:user_emails)
        .where("users.name ILIKE ? OR users.email ILIKE ? OR user_emails.email ILIKE ?", q, q, q)
        .distinct.references(:user_emails)
    end

    def matching_domain(str)
      where("email ILIKE ?", "%#{str.to_s.strip}")
    end

    def search_phone(str)
      q = "%#{Phonifyer.phonify(str)}%"
      includes(:user_phones)
        .where("users.phone ILIKE ? OR user_phones.phone ILIKE ?", q, q)
        .distinct.references(:user_phones)
    end

    def from_auth(auth)
      return nil unless auth&.is_a?(Array)
      where(id: auth[0], auth_token: auth[1]).first
    end
  end

  def additional_emails=(value)
    UserEmail.add_emails_for_user_id(id, value)
  end

  def confirmed_emails
    user_emails.confirmed.pluck(:email)
  end

  def secondary_emails
    user_emails.where.not(email: email).pluck(:email)
  end

  def ensure_unique_email
    return true unless self.class.fuzzy_confirmed_or_unconfirmed_email_find(email)
    return true if id.present? # Because existing users shouldn't see this error
    errors.add(:email, :email_already_exists)
  end

  def member?
    membership_active.present?
  end

  def confirmed?
    confirmed
  end

  def unconfirmed?
    !confirmed?
  end

  # Performed inline
  def perform_create_jobs
    AfterUserCreateJob.new.perform(id, "new", user: self)
  end

  def perform_user_update_jobs
    AfterUserChangeJob.perform_async(id) if id.present? && !skip_update
  end

  def superuser?(controller_name: nil, action_name: nil)
    superuser ||
      superuser_abilities.can_access?(controller_name: controller_name, action_name: action_name)
  end

  def developer?
    developer
  end

  def su_option?(opt)
    superuser_abilities.with_su_option(opt).limit(1).any?
  end

  def banned?
    banned
  end

  def ambassador?
    organization_roles.ambassador_organizations.limit(1).any?
  end

  def to_param
    username
  end

  def display_name
    name.present? ? name : email
  end

  def first_display_name
    display_name.split(" ")&.first
  end

  def donations
    payments.donation.sum(:amount_cents)
  end

  def donor?
    donations > 900
  end

  def theft_alert_purchaser?
    theft_alerts.paid.limit(1).any?
  end

  def organization_prioritized
    return nil if organization_roles.limit(1).none?
    orgs = organizations.reorder(:created_at)
    # Prioritization of organizations
    orgs.ambassador.limit(1).first ||
      orgs.paid_money.limit(1).first ||
      orgs.paid.limit(1).first ||
      orgs.law_enforcement.limit(1).first ||
      orgs.bike_shop.limit(1).first ||
      orgs.limit(1).first
  end

  def paid_org?
    organizations.paid.limit(1).any?
  end

  def authorized?(obj, no_superuser_override: false)
    return true if !no_superuser_override && superuser?
    case obj.class.name
    when "Bike", "BikeVersion"
      obj.authorized?(self, no_superuser_override: no_superuser_override)
    when "Organization" then member_of?(obj)
    when "BikeSticker" then obj.claimable_by?(self)
    else
      false
    end
  end

  def enabled?(slugs, no_superuser_override: false)
    features = OrganizationFeature.matching_slugs(slugs)
    return false if features.blank?
    return true if !no_superuser_override && superuser?
    organizations.with_enabled_feature_slugs(features).limit(1).any?
  end

  def auth_token_time(auth_token_type)
    SecurityTokenizer.token_time(self[auth_token_type])
  end

  def auth_token_expired?(auth_token_type)
    auth_token_time(auth_token_type) < (Time.current - 2.hours)
  end

  def accepted_vendor_terms_of_service?
    vendor_terms_of_service
  end

  def accepted_vendor_terms_of_service=(val)
    return unless InputNormalizer.boolean(val)
    self.vendor_terms_of_service = true
    self.when_vendor_terms_of_service = Time.current
  end

  def send_password_reset_email
    # If the auth token was just created, don't create a new one, it's too error prone
    return false if auth_token_time("token_for_password_reset").to_i > (Time.current - 2.minutes).to_i
    update_auth_token("token_for_password_reset")
    reload # Attempt to ensure the database is updated, so sidekiq doesn't send before update is committed
    EmailResetPasswordJob.perform_async(id)
    true
  end

  def send_magic_link_email
    # If the auth token was just created, don't create a new one, it's too error prone
    return true if auth_token_time("magic_link_token") > Time.current - 1.minutes
    update_auth_token("magic_link_token")
    reload # Attempt to ensure the database is updated, so sidekiq doesn't send before update is committed
    EmailMagicLoginLinkJob.perform_async(id)
  end

  def update_last_login(ip_address)
    save! unless id.present? # throw an error that shows why the user isn't created
    update_columns(last_login_at: Time.current, last_login_ip: ip_address)
  end

  def confirm(token)
    return false if token != confirmation_token
    self.confirmation_token = nil
    self.confirmed = true
    save
    reload
    AfterUserCreateJob.new.perform(id, "confirmed", user: self)
    true
  end

  def role(organization)
    m = OrganizationRole.where(user_id: id, organization_id: organization.id).first
    m&.role
  end

  def member_of?(organization, no_superuser_override: false)
    return false unless organization.present?
    return true if claimed_organization_roles_for(organization.id).limit(1).any?
    superuser? && !no_superuser_override
  end

  def member_bike_edit_of?(organization, no_superuser_override: false)
    return false unless organization.present?
    return true if claimed_organization_roles_for(organization.id).not_member_no_bike_edit.limit(1).any?
    superuser? && !no_superuser_override
  end

  def admin_of?(organization, no_superuser_override: false)
    return false unless organization.present?
    return true if claimed_organization_roles_for(organization.id).admin.limit(1).any?
    superuser? && !no_superuser_override
  end

  def has_organization_role?
    organization_roles.limit(1).any?
  end

  def has_police_organization_role?
    organizations.law_enforcement.limit(1).any?
  end

  def has_shop_organization_role?
    organizations.bike_shop.limit(1).any?
  end

  def deletable?
    !superuser? && organization_roles.admin.limit(1).none?
  end

  def default_organization
    return @default_organization if defined?(@default_organization) # Memoize, permit nil
    @default_organization = organizations&.first # Maybe at some point use organization_roles to get the most recent, for now, speed
  end

  def partner_sign_up
    (partner_data && partner_data["sign_up"].present?) ? partner_data["sign_up"] : nil
  end

  def bikes(user_hidden = true)
    bikes = Bike.unscoped.without_deleted.where(example: false)
    bikes = bikes.where(user_hidden: false) unless user_hidden
    bikes.default_includes.where(ownerships: {user_id: id}).order(:id)
  end

  def bike_ids(user_hidden = true)
    bikes(user_hidden).pluck(:id)
  end

  def recovered_records
    StolenRecord.recovered.where(bike_id: bike_ids)
  end

  # TODO: make this a little more efficient
  def bike_organizations
    bike_org_ids = BikeOrganization.where(bike_id: bike_ids).distinct.pluck(:organization_id)
    Organization.where(id: bike_org_ids)
  end

  def unauthorized_organization_update_bike_sticker_ids
    bike_sticker_updates.successful.unauthorized_organization.distinct.pluck(:bike_sticker_id)
  end

  # Used to render organization address fields on user root, if present. Method here for testing
  def uro_organization_reg_address
    uro_organizations.with_enabled_feature_slugs("reg_address").first
  end

  def render_donation_request
    return nil unless has_police_organization_role? && !organizations.law_enforcement.paid.limit(1).any?
    "law_enforcement"
  end

  def phone_waiting_confirmation?
    user_phones.waiting_confirmation.limit(1).any?
  end

  def current_user_phone
    (user_phones.where(phone: phone).last ||
      user_phones.confirmed.order(:updated_at)&.last)&.phone
  end

  def phone_confirmed?
    user_phones.confirmed.limit(1).any?
  end

  def set_calculated_attributes
    self.preferred_language = nil if preferred_language.blank?
    self.phone = Phonifyer.phonify(phone)
    self.alert_slugs = (alert_slugs || [])
    # Rather than waiting for twilio to send, immediately update alert_slugs
    self.alert_slugs += ["phone_waiting_confirmation"] if phone_changed?
    self.username = Slugifyer.slugify(username) if username
    self.email = EmailNormalizer.normalize(email)
    self.title = InputNormalizer.sanitize(title) if title.present?
    if no_non_theft_notification
      self.notification_newsletters = false
      organization_roles.notification_daily.each { |m| m.update(hot_sheet_notification: :notification_never) }
    end
    if my_bikes_link_target.present? || my_bikes_link_title.present?
      mbh = my_bikes_hash || {}
      mbh["link_target"] = Urlifyer.urlify(my_bikes_link_target)
      mbh["link_title"] = my_bikes_link_title if my_bikes_link_title.present?
      self.my_bikes_hash = mbh
    end
    true
  end

  def mb_link_target
    my_bikes_hash && my_bikes_hash["link_target"]
  end

  def mb_link_title
    my_bikes_hash && my_bikes_hash["link_title"]
  end

  def userlink
    if show_bikes
      "/users/#{username}"
    elsif twitter.present?
      "https://twitter.com/#{twitter}"
    end
  end

  def update_auth_token(auth_token_type, time = nil)
    generate_auth_token(auth_token_type, time)
    save
  end

  def generate_auth_token(auth_token_type, time = nil)
    self.attributes = {auth_token_type => SecurityTokenizer.new_token(time)}
  end

  def access_tokens_for_application(toke)
    Doorkeeper::AccessToken.where(resource_owner_id: id, application_id: toke)
  end

  protected

  def generate_username_confirmation_and_auth
    usrname = username || SecureRandom.urlsafe_base64
    while User.where(username: usrname).where.not(id: id).exists?
      usrname = SecureRandom.urlsafe_base64
    end
    self.username = usrname
    generate_auth_token("confirmation_token") unless confirmed
    generate_auth_token("auth_token")
    true
  end

  private

  def claimed_organization_roles_for(organization_id)
    OrganizationRole.claimed.where(user_id: id, organization_id: organization_id)
  end

  def preferred_language_is_an_available_locale
    return if preferred_language.blank?
    return if I18n.available_locales.include?(preferred_language.to_sym)
    errors.add(:preferred_language, :not_an_available_language)
  end
end
