class BikeStickerUpdate < ApplicationRecord
  KIND_ENUM = {initial_claim: 0, re_claim: 1, un_claim: 2, failed_claim: 3}.freeze
  CREATOR_KIND_ENUM = {creator_user: 0, creator_export: 1, creator_pos: 2}.freeze
  ORGANIZATION_KIND_ENUM = {no_organization: 0, primary_organization: 1, regional_organization: 2, other_organization: 3, other_paid_organization: 4}.freeze

  belongs_to :bike_sticker
  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  enum kind: KIND_ENUM
  enum creator_kind: CREATOR_KIND_ENUM
  enum organization_kind: ORGANIZATION_KIND_ENUM

  scope :successful, -> { where.not(kind: "failed_claim")}
  scope :unauthorized_organization, -> { where(organization_kind: organization_kinds_unauthorized) }

  before_save :set_calculated_attributes

  def self.organization_kinds_unauthorized
    %w[no_organization other_organization]
  end

  def self.organization_kinds_authorized
    ORGANIZATION_KIND_ENUM.keys.map(&:to_s) - organization_kinds_unauthorized
  end

  def unauthorized_organization?
    self.class.organization_kinds_authorized.include?(organization_kind)
  end

  def set_calculated_attributes
    self.creator_kind ||= "creator_user"
    self.organization_kind ||= calculated_organization_kind
  end

  private

  def calculated_organization_kind
    return "no_organization" unless organization.present?
    if organization_id == bike_sticker.organization_id
      "primary_organization"
    elsif bike_sticker.organization&.regional? && organization.regional_parents.pluck(:id).include?(bike_sticker.organization_id)
      "regional_organization"
    else
      "other_organization"
    end
  end
end
