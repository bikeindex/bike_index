# frozen_string_literal: true

class BikeSticker < ApplicationRecord
  KIND_ENUM = {sticker: 0, spokecard: 1}.freeze
  MAX_UNORGANIZED = 20
  belongs_to :bike
  belongs_to :organization
  belongs_to :secondary_organization, class_name: "Organization" # assigning organization
  belongs_to :user # User who assigns the bike
  belongs_to :bike_sticker_batch

  has_many :bike_sticker_updates

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

  def self.calculated_code_integer(str)
    str.present? ? str.gsub(/\A\D+/, "").to_i : nil
  end

  def self.calculated_code_prefix(str)
    str.present? ? str.gsub(/\d+\z/, "").upcase : nil
  end

  def self.code_integer_and_prefix_search(str)
    code_integer = calculated_code_integer(str)
    return none if code_integer > 9223372036854775807 # BigInt max - can't be a larger int than this
    where(code_integer: code_integer, code_prefix: calculated_code_prefix(str))
  end

  def self.organization_search(organization_id)
    if organization_id.present?
      org = Organization.friendly_find(organization_id)
      return where(organization_id: org.id).or(where(secondary_organization_id: org.id)) if org.present?
    end
    BikeSticker.none
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
    bike_sticker ||= matching_codes.organization_search(organization_id).first
    return bike_sticker if bike_sticker.present?
    user_organization_ids = user&.memberships&.pluck(:organization_id) || []
    if user_organization_ids.any?
      bike_sticker ||= matching_codes.where(organization_id: user_organization_ids).first
    end
    bike_sticker ||= matching_codes.first
    bike_sticker ||= organization_search(organization_id).where("code ILIKE ?", "%#{normalized_code}%").first
    bike_sticker || where("code ILIKE ?", "%#{normalized_code}%").first
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

  def claimed?
    bike_id.present? && bike.present?
  end

  def unclaimed?
    !claimed?
  end

  def url
    [
      "#{ENV["BASE_URL"]}/scanned/bikes/#{code}",
      organization.present? ? "?organization_id=#{organization.slug}" : nil
    ].compact.join("")
  end

  def next_unclaimed_code
    BikeSticker.where(organization_id: organization_id).next_unclaimed_code(id)
  end

  def pretty_code
    [code_prefix, code_number_string.scan(/.{1,3}/)]
      .flatten.compact.join(" ")
  end

  def organization_authorized?(passed_organization = nil)
    return false if passed_organization.blank?
    return true if passed_organization.is_paid || passed_organization.ambassador?
    return false unless organization_id.present? # Non-paid organizations can't edit non-organized stickers
    return true if passed_organization.regional_parents.pluck(:id).include?(organization_id)
    passed_organization.id == organization_id
  end

  def claimable_by?(passed_user, passed_organization = nil)
    return false unless passed_user.present?
    return true if passed_user.superuser?
    if passed_organization.present?
      return false unless passed_user.authorized?(passed_organization)
      return true if organization_authorized?(passed_organization)
    elsif passed_user.organizations.detect { |o| organization_authorized?(o) }
      return true
    end
    unauthorized_sticker_ids = passed_user.unauthorized_organization_update_bike_sticker_ids
    return true if unauthorized_sticker_ids.include?(id)
    return bike.authorized?(passed_user) if claimed? # if user is authorized, they can edit
    unauthorized_sticker_ids.count < MAX_UNORGANIZED
  end

  def claiming_bike_for_args(args)
    args[:bike].is_a?(Bike) ? args[:bike] : Bike.friendly_find(args[:bike])
  end

  def claiming_organization_for_args(args)
    args[:organization] || args[:user]&.organizations&.detect { |o| organization_authorized?(o) }
  end

  # Passing as hash so that the keywords don't override the methods here
  # args => user:, bike:, organization:, creator_kind:, export_id:
  # NOTE: bike can be a bike or string (for friendly finding)
  def claim(args = {})
    claiming_bike = claiming_bike_for_args(args)
    claiming_organization = claiming_organization_for_args(args)
    bike_sticker_update = BikeStickerUpdate.new(bike_sticker_id: id, user: args[:user],
                                                organization: claiming_organization, bike: claiming_bike,
                                                safe_assign_creator_kind: args[:creator_kind], export_id: args[:export_id])
    if claiming_bike.blank? && args[:bike].is_a?(String) && args[:bike].length > 0
      not_found = I18n.t(:not_found, scope: %i[activerecord errors models bike_sticker])
      errors.add(:bike, "\"#{args[:bike]}\" #{not_found}")
      bike_sticker_update.add_failed_claim_error("unable to find bike: #{args[:bike]}")
    end
    bike_sticker_update.save
    return self if bike_sticker_update.failed_claim_errors.present?
    self.previous_bike_id = bike_id unless bike_id.blank? || bike_id == claiming_bike&.id
    if claiming_bike.blank?
      update(bike: nil, claimed_at: nil)
    else
      self.secondary_organization = claiming_organization unless claiming_organization == organization
      update(user: args[:user], bike: claiming_bike, claimed_at: Time.current)
      if claiming_organization.present?
        bike.bike_organizations.create(organization_id: claiming_organization.id, can_not_edit_claimed: true)
      end
    end
    self
  end

  # args => same as #claim
  def claim_if_permitted(args = {})
    args[:organization] = claiming_organization_for_args(args)
    return claim(args) if claimable_by?(args[:user], args[:organization])
    errors.add(:user, args[:user].present? ? :unauthorized_to_claim : :not_found)
    BikeStickerUpdate.create(bike_sticker_id: id,
                             user: args[:user],
                             organization: args[:organization],
                             bike: claiming_bike_for_args(args),
                             failed_claim_errors: errors.full_messages.join(", "))
    self
  end

  # Bust cache keys TODO: Rails 5 update test this
  def update_associations
    if bike_id.present?
      found_b = Bike.where(id: bike_id).first
      found_b&.update_attributes(updated_at: Time.current)
    end
  end

  def set_calculated_attributes
    self.code = self.class.normalize_code(code)
    self.code_integer = self.class.calculated_code_integer(code)
    self.code_prefix = self.class.calculated_code_prefix(code)
  end

  private

  def code_number_string
    str = code_integer.to_s
    return str unless bike_sticker_batch&.code_number_length.present?
    str.rjust(bike_sticker_batch.code_number_length, "0")
  end
end
