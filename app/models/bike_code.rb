# frozen_string_literal: true

class BikeCode < ActiveRecord::Base
  KIND_ENUM = { sticker: 0, spokecard: 1 }.freeze
  MAX_UNORGANIZED = 10
  belongs_to :bike
  belongs_to :organization
  belongs_to :user # User who assigns the bike
  belongs_to :bike_code_batch

  scope :claimed, -> { where.not(bike_id: nil) }
  scope :unclaimed, -> { where(bike_id: nil) }

  enum kind: KIND_ENUM

  validates_presence_of :code
  validates_uniqueness_of :code, scope: [:organization_id], allow_nil: false

  before_validation :set_calculated_attributes
  after_commit :update_associations

  def self.normalize_code(str = nil)
    return nil unless str.present?
    code = str.to_s.upcase.strip.gsub(/\s*/, "")
    if code.match?(/BIKEINDEX.ORG/)
      code = code.gsub(%r{\A.*BIKEINDEX.ORG/BIKES}, "").gsub(/\?.*/, "") # Remove the start and query string
      code = code.gsub(%r{/SCANNED/?}, "").gsub(%r{(\A/)|(/\z)}, "") # Remove scanned, wherever it is, and a trailing / if it exists
    end
    code.gsub(/\A0*/, "") # Strip leading 0s, because we don't care about them
  end

  def self.calculated_code_integer(str); str.present? ? str.gsub(/\A\D+/, "").to_i : nil end

  def self.calculated_code_prefix(str); str.present? ? str.gsub(/\d+\z/, "").upcase : nil end

  def self.code_integer_and_prefix_search(str)
    where(code_integer: calculated_code_integer(str), code_prefix: calculated_code_prefix(str))
  end

  def self.organization_search(organization_id)
    if organization_id.present?
      org = Organization.friendly_find(organization_id)
      return where(organization_id: org.id) if org.present?
    end
    # Sorta ugly, but this needs to return an empty active record collection
    where(organization_id: 0)
  end

  # organization_id can be any organization identifier (name, slug, id)
  # generally don't pass in normalized_code
  def self.lookup(str, organization_id: nil)
    normalized_code = normalize_code(str)
    matching_codes = code_integer_and_prefix_search(normalized_code)
    matching_codes.organization_search(organization_id).first || matching_codes.first
  end

  def self.lookup_with_fallback(str, organization_id: nil, user: nil)
    return nil unless str.present?
    normalized_code = normalize_code(str)
    matching_codes = code_integer_and_prefix_search(normalized_code)
    bike_code ||= matching_codes.organization_search(organization_id).first
    return bike_code if bike_code.present?
    user_organization_ids = user&.memberships&.pluck(:organization_id) || []
    if user_organization_ids.any?
      bike_code ||= matching_codes.where(organization_id: user_organization_ids).first
    end
    bike_code ||= matching_codes.first
    bike_code ||= organization_search(organization_id).where("code ILIKE ?", "%#{normalized_code}%").first
    bike_code ||= where("code ILIKE ?", "%#{normalized_code}%").first
  end

  def self.admin_text_search(str)
    normalized_code = normalize_code(str)
    return all unless normalized_code.present?
    where("code ILIKE ?", "%#{normalized_code}%")
  end

  def self.next_unclaimed_code(after_id = nil)
    after_id ||= claimed.order(:id).last&.id || 1 # So we can pass in the id to iterate from.
    # If there aren't any claimed stickers, we need to include a number or this returns nil
    unclaimed.reorder(:id).where("id > ?", after_id || 1).first
  end

  def claimed?; bike_id.present? end

  def unclaimed?; !claimed? end

  def url
    [
      "#{ENV["BASE_URL"]}/scanned/bikes/#{code}",
      organization.present? ? "?organization_id=#{organization.slug}" : nil,
    ].compact.join("")
  end

  def next_unclaimed_code
    BikeCode.where(organization_id: organization_id).next_unclaimed_code(id)
  end

  def pretty_code
    [code_prefix, code_integer.to_s.scan(/.{1,3}/)]
      .flatten.compact.join(" ")
  end

  def claimable_by?(user)
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

  def unclaimable_by?(user)
    return false unless errors.none? && claimed?
    organization.present? && user.member_of?(organization) || user.authorized?(bike)
  end

  def unclaim!
    self.previous_bike_id = bike_id if bike_id.present?
    update(bike_id: nil, user_id: nil, claimed_at: nil)
  end

  def claim(user, bike_str, claiming_bike: nil)
    errors.add(:user, "not found") unless user.present?
    claiming_bike ||= Bike.friendly_find(bike_str)
    # Check bike_str, not bike_id, because we don't want to allow people adding bikes
    if bike_str.blank? && claiming_bike.blank? && unclaimable_by?(user)
      unclaim!
    elsif claiming_bike.present?
      self.previous_bike_id = bike_id || previous_bike_id # Don't erase previous_bike_id if double unclaiming
      update(bike_id: claiming_bike.id, user_id: user.id, claimed_at: Time.current) unless errors.any?
    else
      errors.add(:bike, "\"#{bike_str}\" not found")
    end
    self
  end

  # Bust cache keys TODO: Rails 5 update test this
  def update_associations
    if bike_id.present?
      found_b = Bike.where(id: bike_id).first
      found_b&.update_attributes(updated_at: Time.current)
    end
    if previous_bike_id.present?
      found_previous_b = Bike.where(id: previous_bike_id).first
      found_previous_b&.update_attributes(updated_at: Time.current)
    end
  end

  def set_calculated_attributes
    self.code = self.class.normalize_code(code)
    self.code_integer = self.class.calculated_code_integer(code)
    self.code_prefix = self.class.calculated_code_prefix(code)
  end
end
