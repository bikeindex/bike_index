class BikeStickerUpdate < ApplicationRecord
  KIND_ENUM = {initial_claim: 0, re_claim: 1, un_claim: 2, failed_claim: 3}.freeze
  CREATOR_KIND_ENUM = {creator_user: 0, creator_primary_organization: 1, creator_regional_organization: 2, creator_other_organization: 3}

  belongs_to :bike_sticker
  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  enum kind: KIND_ENUM
  enum creator_kind: CREATOR_KIND_ENUM

  scope :pos_claim, -> { where(pos_claim: true) }

  before_save :set_calculated_attributes

  def set_calculated_attributes
    self.organization ||= calculated_organization
    self.creator_kind ||= calculated_creator_kind
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

  def calculated_creator_kind
    return "creator_user" unless organization_id.present?
    if organization_id == bike_sticker.organization_id
      "creator_primary_organization"
    elsif bike_sticker.organization.regional? && organization.regional_parents.pluck(:id).include?(bike_sticker.organization_id)
      "creator_regional_organization"
    else
      "creator_other_organization"
    end
  end
end
