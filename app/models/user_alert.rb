# == Schema Information
#
# Table name: user_alerts
# Database name: primary
#
#  id              :bigint           not null, primary key
#  dismissed_at    :datetime
#  kind            :integer
#  message         :text
#  resolved_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  b_param_id      :bigint
#  bike_id         :bigint
#  organization_id :bigint
#  theft_alert_id  :bigint
#  user_id         :bigint
#  user_phone_id   :bigint
#
# Indexes
#
#  index_user_alerts_on_b_param_id      (b_param_id)
#  index_user_alerts_on_bike_id         (bike_id)
#  index_user_alerts_on_theft_alert_id  (theft_alert_id)
#  index_user_alerts_on_user_id         (user_id)
#  index_user_alerts_on_user_phone_id   (user_phone_id)
#
class UserAlert < ApplicationRecord
  KIND_ENUM = {
    phone_waiting_confirmation: 0,
    theft_alert_without_photo: 1,
    stolen_bike_without_location: 2,
    unassigned_bike_org: 3,
    unfinished_registration: 4
  }.freeze

  enum :kind, KIND_ENUM

  belongs_to :user
  belongs_to :b_param
  belongs_to :bike
  belongs_to :user_phone
  belongs_to :theft_alert
  belongs_to :organization

  has_one :notification, as: :notifiable

  validates :user_phone_id, uniqueness: {scope: %i[kind user_id]}, allow_blank: true

  before_validation :set_calculated_attributes

  scope :dismissed, -> { where.not(dismissed_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :inactive, -> { where.not(resolved_at: nil).or(where(dismissed_at: nil)) }
  scope :active, -> { where(resolved_at: nil, dismissed_at: nil) }
  scope :ignored_member, -> { where(kind: ignored_kinds_member) }
  scope :ignored_superuser, -> { where(kind: ignored_kinds_superuser) }
  scope :general, -> { where(kind: general_kinds) }
  scope :account, -> { where(kind: account_kinds) }
  scope :dismissable, -> { where(kind: dismissable_kinds) }
  scope :with_notification, -> { joins(:notification).where.not(notifications: {id: nil}) }
  scope :create_notification, -> {
    where(kind: notification_kinds, updated_at: notify_period)
      .left_joins(:notification).where(notifications: {id: nil})
  }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.kind_humanized(str)
    return "" unless str.present?

    str.tr("_", " ")
  end

  def self.ignored_kinds_superuser
    ignored_kinds_member + %w[theft_alert_without_photo unassigned_bike_org]
  end

  def self.ignored_kinds_member
    %w[stolen_bike_without_location unassigned_bike_org]
  end

  def self.dismissable_kinds
    %w[unassigned_bike_org]
  end

  # Highest priority first - only one general alert renders, and this is the order it picks
  def self.general_kinds
    %w[phone_waiting_confirmation stolen_bike_without_location theft_alert_without_photo
      unfinished_registration]
  end

  # phone_verification gates the only kind behind a flag
  def self.disabled_kinds
    Flipper.enabled?(:phone_verification) ? [] : %w[phone_waiting_confirmation]
  end

  def self.account_kinds
    %w[unassigned_bike_org]
  end

  def self.notification_kinds
    %w[theft_alert_without_photo stolen_bike_without_location]
  end

  def self.notify_period
    (Time.current - 2.weeks)..(Time.current - 1.hour)
  end

  def self.placement(kind)
    account_kinds.include?(kind) ? "account" : "general"
  end

  def self.find_or_build_by(attrs)
    where(attrs).first || new(attrs)
  end

  # The denormalized copy on the user, which gates whether any alert renders at all
  def self.refresh_alert_slugs(user)
    slugs = where(user_id: user.id).active.distinct.pluck(:kind).sort
    return true if user.alert_slugs == slugs

    # Straight to the column: this runs in the register flow's request now, and User's
    # uniqueness validations cost four selects before the update. updated_at explicitly,
    # since the job bumps it to bust the cache
    user.update_columns(alert_slugs: slugs, updated_at: Time.current)
  end

  def self.update_unfinished_registrations(user)
    user.b_params.unfinished_registrations
      .each { |b_param| update_unfinished_registration(user:, b_param:) }

    # A registration that expired (or was deleted) is out of the scope above, and nobody
    # saves an abandoned one again - so this is the only thing that resolves its alert
    user.user_alerts.active.unfinished_registration.includes(:b_param)
      .reject { |user_alert| user_alert.b_param&.unfinished_registration? }
      .each(&:resolve!)
  end

  def self.update_unfinished_registration(user:, b_param:)
    user_alert = find_or_build_by(kind: "unfinished_registration",
      user_id: user.id, b_param_id: b_param.id)
    if b_param.unfinished_registration?
      user_alert.save
    else # Don't create just to resolve
      user_alert.id.blank? || user_alert.resolve!
    end
  end

  def self.update_theft_alert_without_photo(user:, theft_alert:)
    # scope to just active, to alert if the theft alert once again has no image
    user_alert = UserAlert.active.find_or_build_by(kind: "theft_alert_without_photo",
      user_id: user.id, theft_alert_id: theft_alert.id)
    if theft_alert.missing_photo?
      user_alert.bike_id = theft_alert.bike&.id
      user_alert.save
    else # Don't create just to resolve
      user_alert.id.blank? || user_alert.resolve!
    end
  end

  def self.update_stolen_bike_without_location(user:, bike:)
    user_alert = UserAlert.find_or_build_by(kind: "stolen_bike_without_location",
      user_id: user.id, bike_id: bike.id)
    if bike.current_stolen_record&.without_street?
      user_alert.save
    else # Don't create just to resolve
      user_alert.id.blank? || user_alert.resolve!
    end
  end

  def self.update_unassigned_bike_org(user:, organization:, bike:)
    user_alert = UserAlert.find_or_build_by(kind: "unassigned_bike_org",
      user_id: user.id, organization_id: organization.id, bike_id: bike.id)
    if bike.organizations.where(id: organization.id).none?
      user_alert.save
    else
      # Don't create if theft alert already has a photo
      user_alert.id.blank? || user_alert.resolve!
    end
  end

  def self.update_phone_waiting_confirmation(user:, user_phone:)
    user_alert = UserAlert.find_or_build_by(kind: "phone_waiting_confirmation",
      user_id: user.id, user_phone_id: user_phone.id)
    if user_phone.confirmed?
      # Don't create if phone is already confirmed
      user_alert.id.blank? || user_alert.resolve!
    else
      user_alert.save unless user_phone.legacy?
    end
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def dismissable?
    self.class.dismissable_kinds.include?(kind)
  end

  def placement
    self.class.placement(kind)
  end

  def general?
    self.class.general_kinds.include?(kind)
  end

  def account?
    self.class.account_kinds.include?(kind)
  end

  def dismissed?
    dismissed_at.present?
  end

  def resolved?
    resolved_at.present?
  end

  def inactive?
    dismissed? || resolved?
  end

  def active?
    !inactive?
  end

  def dismiss!
    return true if dismissed?

    update(dismissed_at: Time.current)
  end

  def resolve!
    return true if resolved?

    update(resolved_at: Time.current)
  end

  def create_notification?
    return false if inactive? || notification.present? ||
      !self.class.notify_period.cover?(updated_at) ||
      self.class.notification_kinds.exclude?(kind)

    # Check if the relevant object is updated since
    if theft_alert_without_photo? || stolen_bike_without_location?
      return false if bike.blank? || !self.class.notify_period.cover?(bike.updated_at) ||
        !bike.current_stolen_record&.receive_notifications
    end
    # don't send a user alert notification if user has an outstanding user alert notification
    UserAlert.active.where(user_id: user_id).with_notification.none?
  end

  def email_subject
    if kind == "theft_alert_without_photo"
      "Your stolen #{bike.cycle_type} needs a photo"
    elsif kind == "stolen_bike_without_location"
      "Your stolen #{bike.cycle_type} is missing its location"
    else
      kind_humanized
    end
  end

  def set_calculated_attributes
    self.message = nil if message.blank?
  end
end
