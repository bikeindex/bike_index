# frozen_string_literal: true

# == Schema Information
#
# Table name: bike_stickers
#
#  id                        :integer          not null, primary key
#  claimed_at                :datetime
#  code                      :string
#  code_integer              :bigint
#  code_number_length        :integer
#  code_prefix               :string
#  kind                      :integer          default("sticker")
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  bike_id                   :integer
#  bike_sticker_batch_id     :integer
#  organization_id           :integer
#  previous_bike_id          :integer
#  secondary_organization_id :bigint
#  user_id                   :integer
#
# Indexes
#
#  index_bike_stickers_on_bike_id                    (bike_id)
#  index_bike_stickers_on_bike_sticker_batch_id      (bike_sticker_batch_id)
#  index_bike_stickers_on_secondary_organization_id  (secondary_organization_id)
#
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

  enum :kind, KIND_ENUM

  validates_presence_of :code
  validates_uniqueness_of :code, scope: [:organization_id], allow_nil: false

  before_validation :set_calculated_attributes
  after_commit :update_associations

  class << self
    def normalize_code(str = nil, leading_zeros: false, one_zero: false)
      return nil unless str.present?
      code = str.to_s.upcase.strip.gsub(/\s*/, "")
      if code.match?(/BIKEINDEX.ORG/)
        code = code.gsub(%r{\A.*BIKEINDEX.ORG/BIKES}, "").gsub(/\?.*/, "") # Remove the start and query string
        code = code.gsub(%r{/SCANNED/?}, "").gsub(%r{(\A/)|(/\z)}, "") # Remove scanned, wherever it is, and a trailing / if it exists
      end
      # split into letters/numbers
      result = code.scan(/[^\d]+|\d+/).map { |seg|
        next seg if leading_zeros
        seg.gsub(/\A0*/, "") # Strip leading 0s, because we don't care about them - wherever they occur
      }.join("")
      return result unless one_zero && !result.match?(/\d/)
      "#{result}0"
    end

    def calculated_code_integer(str)
      return str if str.is_a?(Integer)
      numbers = calculated_code_numbers(str)
      numbers.present? ? numbers.to_i : nil
    end

    def calculated_code_prefix(str)
      str.present? ? str.gsub(/\d+\z/, "").upcase : nil
    end

    def code_integer_and_prefix_search(str)
      normalized_code_with_zeroes = normalize_code(str, leading_zeros: true)
      code_integer = calculated_code_integer(normalized_code_with_zeroes)
      return none if code_integer.present? && code_integer > 9223372036854775807 # BigInt max - can't be a larger int than this
      code_number_length = calculated_code_numbers(normalized_code_with_zeroes).length
      lookup_query = {}
      lookup_query[:code_integer] = code_integer if code_integer.present?
      code_prefix = calculated_code_prefix(normalized_code_with_zeroes)
      lookup_query[:code_prefix] = code_prefix if code_prefix.present?
      where(lookup_query).of_length(code_number_length).order(:id)
    end

    # organization_id can be any organization identifier (name, slug, id)
    # generally don't pass in normalized_code
    def lookup(str, organization_id: nil)
      matching_codes = code_integer_and_prefix_search(str)
      matching_codes.organization_search(organization_id).first || matching_codes.first
    end

    # Similar to lookup, but attempts to find the sticker even if it isn't an exact match
    def lookup_with_fallback(str, organization_id: nil, user: nil)
      return nil unless str.present?
      # Fix sticker misprint
      if organization_id.blank? && str.match?(/organization_id=/)
        str, organization_id = str.split("organization_id=")
      end
      matching_codes = code_integer_and_prefix_search(str)
      bike_sticker ||= matching_codes.organization_search(organization_id).first
      return bike_sticker if bike_sticker.present?
      user_organization_ids = user&.organization_roles&.pluck(:organization_id) || []
      if user_organization_ids.any?
        bike_sticker ||= matching_codes.where(organization_id: user_organization_ids).first
      end
      bike_sticker ||= matching_codes.first
      return bike_sticker if bike_sticker.present?
      normalized_code = normalize_code(str)
      bike_sticker ||= organization_search(organization_id).where("code ILIKE ?", "%#{normalized_code}%").first
      bike_sticker || where("code ILIKE ?", "%#{normalized_code}%").first
    end

    def sticker_code_search(str)
      normalized_code_with_zeroes = normalize_code(str, leading_zeros: true)
      return all unless normalized_code_with_zeroes.present?

      if search_matches_start_with?(str, normalized_code_with_zeroes)
        sticker_code_search_starting_with(normalized_code_with_zeroes)
      else
        normalized_code = normalize_code(normalized_code_with_zeroes)
        where("code ILIKE ?", "%#{normalized_code}%")
      end
    end

    def next_unclaimed_code(after_id = nil)
      after_id ||= claimed.order(:id).last&.id || 1 # So we can pass in the id to iterate from.
      # If there aren't any claimed stickers, we need to include a number or this returns nil
      unclaimed.reorder(:id).where("id > ?", after_id || 1).first
    end

    def user_can_claim_sticker?(user, bike_sticker = nil)
      return false if user.blank?
      return true if user.superuser?
      unauthorized_sticker_ids = user.unauthorized_organization_update_bike_sticker_ids
      if bike_sticker.present?
        # If the user has already updated this sticker, they're allowed to update it again
        return true if unauthorized_sticker_ids.include?(bike_sticker.id)
        # if claimed, the sticker can only be updated if the user is authorized for the current bike
        return bike_sticker.bike.authorized?(user) if bike_sticker.claimed?
      end
      unauthorized_sticker_ids.count < MAX_UNORGANIZED
    end

    def of_length(int)
      where("bike_stickers.code_number_length >= ?", int)
    end

    def organization_search(organization_id)
      if organization_id.present?
        org = Organization.friendly_find(organization_id)
        return where(organization_id: org.id).or(where(secondary_organization_id: org.id)) if org.present?
      end
      BikeSticker.none
    end

    private

    def search_matches_start_with?(str = nil, normalized_code_with_zeroes = nil)
      normalized_code_with_zeroes ||= normalize_code(str, leading_zeros: true)
      return false if normalized_code_with_zeroes.blank?
      normalized_code_with_zeroes.start_with?("0") || normalized_code_with_zeroes.match?(/\D\d/)
    end

    def calculated_code_numbers(str)
      str&.to_s&.gsub(/\A\D+/, "")
    end

    def sticker_code_search_starting_with(normalized_code_with_zeroes)
      code_integer = calculated_code_integer(normalized_code_with_zeroes)
      code_prefix = calculated_code_prefix(normalized_code_with_zeroes)
      results = self
      results = results.where("code ILIKE ?", "%#{code_prefix}%") if code_prefix.present?
      return results if code_integer.blank?
      return results.where(code_integer: 0) if code_integer == 0
      results = results.where("code_integer::text LIKE ?", "#{code_integer}%")
      leading_zeros = normalized_code_with_zeroes.gsub(/\D/, "")[/\A0+/]
      return results if leading_zeros.blank?
      code_number_length = results.maximum(:code_number_length)
      max_digits = (code_number_length || 4) - leading_zeros.length

      results.where("code_integer < ?", ("9" * max_digits).to_i)
        .of_length(calculated_code_numbers(normalized_code_with_zeroes).length)
    end
  end

  def user_editable?
    organization.blank? || organization.enabled?("bike_stickers_user_editable")
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
    if passed_organization.present?
      return true if passed_user.authorized?(passed_organization) &&
        organization_authorized?(passed_organization)
    elsif passed_user.organizations.detect { |o| organization_authorized?(o) }
      return true
    end
    self.class.user_can_claim_sticker?(passed_user, self)
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
      export_id: args[:export_id], safe_assign_creator_kind: args[:creator_kind])
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
      self.secondary_organization = claiming_organization if claiming_organization != organization
      update(user: args[:user], bike: claiming_bike, claimed_at: Time.current)
      add_bike_organizations_if_authorized(args[:user], claiming_bike, claiming_organization)
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
      found_b&.update(updated_at: Time.current)
    end
  end

  def set_calculated_attributes
    return if id.present? # no need to recalculate these every time
    self.code_number_length = calculated_code_number_length
    self.code = self.class.normalize_code(code, one_zero: true)
    self.code_integer = self.class.calculated_code_integer(code)
    self.code_prefix = self.class.calculated_code_prefix(code)
  end

  private

  def calculated_code_number_length
    return bike_sticker_batch.code_number_length if bike_sticker_batch&.code_number_length.present?
    # In production, stickers should only be created with batches. This is really only for testing
    code.gsub(/\D/, "").length
  end

  def code_number_string
    str = code_integer.to_s
    return str unless bike_sticker_batch&.code_number_length.present?
    str.rjust(bike_sticker_batch.code_number_length, "0")
  end

  # NOTE: Only add organization to bike if user is authorized for the bike
  # ... otherwise, organizations could see any bike owner email by linking a sticker
  #  - also, if a regional organization is adding a sticker, don't add the primary organization
  def add_bike_organizations_if_authorized(claiming_user, claiming_bike, claiming_organization)
    return false unless user.present? && claiming_bike.present? && user.authorized?(claiming_bike)
    if claiming_organization.present?
      claiming_bike.bike_organizations.create(organization_id: claiming_organization.id, can_not_edit_claimed: true)
    elsif organization.present?
      claiming_bike.bike_organizations.create(organization_id: organization.id, can_not_edit_claimed: true)
    end
  end
end
