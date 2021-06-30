class UserAlert < ApplicationRecord
  KIND_ENUM = {
    phone_waiting_confirmation: 0,
    theft_alert_without_photo: 1,
    stolen_bike_without_location: 2,
    unassigned_bike_org: 3
  }.freeze

  belongs_to :user
  belongs_to :bike
  belongs_to :user_phone
  belongs_to :theft_alert
  belongs_to :organization

  validates :user_phone_id, uniqueness: {scope: [:kind, :user_id]}, allow_blank: true

  enum kind: KIND_ENUM

  before_validation :set_calculated_attributes

  scope :dismissed, -> { where.not(dismissed_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :inactive, -> { where.not(resolved_at: nil).or(where(dismissed_at: nil)) }
  scope :active, -> { where(resolved_at: nil, dismissed_at: nil) }
  scope :ignored_admin_member, -> { where(kind: ignored_kinds_admin_member) }
  scope :ignored_superuser, -> { where(kind: ignored_kinds_superuser) }
  scope :general, -> { where(kind: general_kinds) }
  scope :account, -> { where(kind: account_kinds) }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.kind_humanized(str)
    return "" unless str.present?
    str.tr("_", " ")
  end

  def self.ignored_kinds_superuser
    ignored_kinds_admin_member + %w[theft_alert_without_photo unassigned_bike_org]
  end

  def self.ignored_kinds_admin_member
    %w[stolen_bike_without_location]
  end

  def self.general_kinds
    %w[phone_waiting_confirmation theft_alert_without_photo stolen_bike_without_location]
  end

  def self.account_kinds
    %w[unassigned_bike_org]
  end

  def self.placement(kind)
    account_kinds.include?(kind) ? "account" : "general"
  end

  def self.find_or_build_by(attrs)
    where(attrs).first || new(attrs)
  end

  def self.update_theft_alert_without_photo(user:, theft_alert:)
    # scope to just active, to alert if the theft alert once again has no image
    user_alert = UserAlert.active.find_or_build_by(kind: "theft_alert_without_photo",
                                                   user_id: user.id, theft_alert_id: theft_alert.id)
    if theft_alert.missing_photo?
      user_alert.bike_id = theft_alert.bike&.id
      user_alert.save
    else
      # Don't create if theft alert already has a photo
      user_alert.id.blank? ? true : user_alert.resolve!
    end
  end

  def self.update_stolen_bike_without_location(user:, bike:)
    user_alert = UserAlert.find_or_build_by(kind: "stolen_bike_without_location",
                                            user_id: user.id, bike_id: bike.id)
    if bike.current_stolen_record&.without_location?
      user_alert.save
    else
      # Don't create if theft alert already has a photo
      user_alert.id.blank? ? true : user_alert.resolve!
    end
  end

  def self.update_unassigned_bike_org(user:, organization:, bike:)
    user_alert = UserAlert.find_or_build_by(kind: "unassigned_bike_org",
                                            user_id: user.id, organization_id: organization.id, bike_id: bike.id)
    if bike.organizations.where(id: organization.id).none?
      user_alert.save
    else
      # Don't create if theft alert already has a photo
      user_alert.id.blank? ? true : user_alert.resolve!
    end
  end

  def self.update_phone_waiting_confirmation(user:, user_phone:)
    user_alert = UserAlert.find_or_build_by(kind: "phone_waiting_confirmation",
                                            user_id: user.id, user_phone_id: user_phone.id)
    if user_phone.confirmed?
      # Don't create if phone is already confirmed
      user_alert.id.blank? ? true : user_alert.resolve!
    else
      user_alert.save unless user_phone.legacy?
    end
  end

  def kind_humanized
    self.class.kind_humanized(kind)
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

  def set_calculated_attributes
  end
end
