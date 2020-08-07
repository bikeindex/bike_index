class BikeStickerUpdate < ApplicationRecord
  KIND_ENUM = {initial_claim: 0, re_claim: 1, un_claim: 2, failed_claim: 3}.freeze
  CREATOR_KIND_ENUM = {creator_user: 0, creator_export: 1, creator_pos: 2}.freeze
  ORGANIZATION_KIND_ENUM = {no_organization: 0, primary_organization: 1, regional_organization: 2, other_organization: 3, other_paid_organization: 4}.freeze

  belongs_to :bike_sticker
  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :export

  enum kind: KIND_ENUM
  enum creator_kind: CREATOR_KIND_ENUM
  enum organization_kind: ORGANIZATION_KIND_ENUM

  scope :successful, -> { where.not(kind: "failed_claim") }
  scope :unauthorized_organization, -> { where(organization_kind: organization_kinds_unauthorized) }

  before_save :set_calculated_attributes

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.organization_kinds
    ORGANIZATION_KIND_ENUM.keys.map(&:to_s)
  end

  def self.organization_kinds_unauthorized
    %w[no_organization other_organization]
  end

  def self.organization_kinds_authorized
    kinds - organization_kinds_unauthorized
  end

  def self.creator_kinds
    CREATOR_KIND_ENUM.keys.map(&:to_s)
  end

  def previous_successful_updates
    BikeStickerUpdate.where(bike_sticker_id: bike_sticker_id).successful
      .where("created_at < ?", created_at || Time.current)
  end

  def unauthorized_organization?
    !self.class.organization_kinds_authorized.include?(organization_kind)
  end

  def add_failed_claim_error(str_or_array)
    self.failed_claim_errors = [
      (failed_claim_errors || nil),
      Array(str_or_array)
    ].flatten.compact.join(", ")
  end

  def safe_assign_creator_kind=(val)
    return unless CREATOR_KIND_ENUM.keys.map(&:to_s).include?(val.to_s)
    self.creator_kind = val
  end

  def set_calculated_attributes
    self.creator_kind ||= export_id.present? ? "creator_export" : "creator_user"
    self.organization_kind ||= calculated_organization_kind
    self.kind ||= calculated_kind
    self.update_number ||= previous_successful_updates.count + 1
  end

  private

  def calculated_organization_kind
    return "no_organization" unless organization.present?
    if organization_id == bike_sticker.organization_id
      "primary_organization"
    elsif bike_sticker.organization&.regional? && organization.regional_parents.pluck(:id).include?(bike_sticker.organization_id)
      "regional_organization"
    elsif organization.paid?
      "other_paid_organization"
    else
      "other_organization"
    end
  end

  def calculated_kind
    return "failed_claim" if failed_claim_errors.present?
    return "un_claim" if bike_id.blank?
    previous_successful_updates.any? ? "re_claim" : "initial_claim"
  end
end
