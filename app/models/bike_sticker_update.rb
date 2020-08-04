class BikeStickerUpdate < ApplicationRecord
  KIND_ENUM = {initial_claim: 0, re_claim: 1, un_claim: 2, failed_claim: 3}.freeze
  CREATOR_KIND_ENUM = {creator_user: 0, creator_export: 1, creator_pos: 2}.freeze
  ORGANIZATION_KIND_ENUM = {no_organization: 0, primary_organization: 1, regional_organization: 2, other_organization: 3}.freeze

  belongs_to :bike_sticker
  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  enum kind: KIND_ENUM
  enum creator_kind: CREATOR_KIND_ENUM
  enum organization_kind: ORGANIZATION_KIND_ENUM

  before_save :set_calculated_attributes

  def set_calculated_attributes
    self.creator_kind ||= "creator_user"
    self.organization ||= calculated_organization
    self.organization_kind ||= calculated_organization_kind
  end

  private

  def calculated_organization
    return nil unless user.present?
    if bike_sticker.organization.present?
      if user.authorized?(bike_sticker.organization)
        update_organization = bike_sticker.organization
      elsif bike_sticker.organization.regional?
        update_organization = user.organizations.where(id: bike_sticker.organization.regional_ids).first
        update_organization ||= user.organizations.ambassador.first
      end
    end
    update_organization || user.organizations.first
  end

  def calculated_organization_kind
    return "no_organization" unless organization_id.present?
    if organization_id == bike_sticker.organization_id
      "primary_organization"
    elsif bike_sticker.organization.regional? && organization.regional_parents.pluck(:id).include?(bike_sticker.organization_id)
      "regional_organization"
    else
      "other_organization"
    end
  end
end
