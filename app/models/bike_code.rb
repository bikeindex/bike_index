# frozen_string_literal: true

class BikeCode < ActiveRecord::Base
  KIND_ENUM = { sticker: 0, spokecard: 1 }.freeze
  MAX_UNORGANIZED = 10
  belongs_to :bike
  belongs_to :organization
  belongs_to :user # User who assigns the bike

  scope :claimed, -> { where.not(bike_id: nil) }
  scope :unclaimed, -> { where(bike_id: nil) }

  enum kind: KIND_ENUM

  validates_presence_of :code
  validates_uniqueness_of :code, scope: [:organization_id], allow_nil: false

  before_validation :set_calculated_attributes

  def self.normalize_code(code = nil)
    code.to_s.upcase.strip.gsub(/\A0*/, "") # Strip leading 0s, because we don't care about them
  end

  def self.lookup(str, organization_id: nil)
    code = normalize_code(str)
    if organization_id.present?
      org = Organization.friendly_find(organization_id)
      return where(code: code, organization_id: org.id).first if org.present?
    end
    where(code: code).first
  end

  def claimed?; bike_id.present? end
  def unclaimed?; !claimed? end

  def linkable_by?(user)
    return false unless user.present?
    return true if user.superuser?
    user_organization_ids = user.memberships.pluck(:organization_id)
    return true if user_organization_ids.include?(organization_id)
    return false if claimed?
    # Because the way activerecord where.not works in rails 4, we need this nil explicitly
    total_codes = BikeCode.where(user_id: user.id).where(organization_id: nil).count
    total_codes += BikeCode.where(user_id: user.id).where.not(organization_id: user_organization_ids).count
    total_codes < MAX_UNORGANIZED
  end

  def claim(user, bike_str)
    errors.add(:user, "not found") unless user.present?
    bike_str = bike_str.to_s.strip
    if bike_str.match(/^\d+\z/) # it's only numbers, so it's a timestamp
      bike_id = bike_str
    else
      bike_id = bike_str.match(/bikes\/\d*/i)
      bike_id = bike_id && bike_id[0].gsub(/bikes./, "") || nil
    end
    new_bike = Bike.where(id: bike_id).first if bike_id.present?
    errors.add(:bike, "\"#{bike_id}\" not found") unless new_bike.present?
    return self if errors.any?
    update(bike_id: new_bike.id, user_id: user.id)
    self
  end

  def set_calculated_attributes
    self.code = self.class.normalize_code(code)
  end
end
