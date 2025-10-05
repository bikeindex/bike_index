# == Schema Information
#
# Table name: bike_sticker_updates
#
#  id                  :bigint           not null, primary key
#  creator_kind        :integer
#  failed_claim_errors :text
#  kind                :integer
#  organization_kind   :integer
#  update_number       :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  bike_id             :bigint
#  bike_sticker_id     :bigint
#  bulk_import_id      :bigint
#  export_id           :bigint
#  organization_id     :bigint
#  user_id             :bigint
#
# Indexes
#
#  index_bike_sticker_updates_on_bike_id          (bike_id)
#  index_bike_sticker_updates_on_bike_sticker_id  (bike_sticker_id)
#  index_bike_sticker_updates_on_bulk_import_id   (bulk_import_id)
#  index_bike_sticker_updates_on_export_id        (export_id)
#  index_bike_sticker_updates_on_organization_id  (organization_id)
#  index_bike_sticker_updates_on_user_id          (user_id)
#
class BikeStickerUpdate < ApplicationRecord
  KIND_ENUM = {initial_claim: 0, re_claim: 1, un_claim: 2, failed_claim: 3, admin_reassign: 4}.freeze
  CREATOR_KIND_ENUM = {creator_user: 0, creator_export: 1, creator_pos: 2, creator_bike_creation: 3, creator_import: 4}.freeze
  ORGANIZATION_KIND_ENUM = {no_organization: 0, primary_organization: 1, regional_organization: 2, other_organization: 3, other_paid_organization: 4}.freeze

  belongs_to :bike_sticker
  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :export
  belongs_to :bulk_import

  enum :kind, KIND_ENUM
  enum :creator_kind, CREATOR_KIND_ENUM
  enum :organization_kind, ORGANIZATION_KIND_ENUM

  scope :successful, -> { where(kind: successful_kinds) }
  scope :unauthorized_organization, -> { where(organization_kind: organization_kinds_unauthorized) }

  before_save :set_calculated_attributes

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.successful_kinds
    kinds - %w[failed_claim admin_reassign]
  end

  def self.organization_kinds
    ORGANIZATION_KIND_ENUM.keys.map(&:to_s)
  end

  def self.organization_kinds_unauthorized
    %w[no_organization other_organization]
  end

  def self.organization_kinds_authorized
    organization_kinds - organization_kinds_unauthorized
  end

  def self.creator_kinds
    CREATOR_KIND_ENUM.keys.map(&:to_s)
  end

  def self.kind_humanized(str)
    return "" unless str.present?
    return str.tr("_", "-") if %w[re_claim un_claim].include?(str)

    str.tr("_", " ")
  end

  def self.creator_kind_humanized(str)
    return "" unless str.present?
    return "bike registration" if str == "creator_bike_creation"

    str.gsub("creator_", "").tr("_", " ")
  end

  def self.organization_kind_humanized(str)
    return "" unless str.present?

    str.tr("_", " ")
  end

  def previous_successful_updates
    BikeStickerUpdate.where(bike_sticker_id: bike_sticker_id).successful
      .where("created_at < ?", created_at || Time.current)
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def creator_kind_humanized
    self.class.creator_kind_humanized(creator_kind)
  end

  def organization_kind_humanized
    self.class.organization_kind_humanized(organization_kind)
  end

  def unauthorized_organization?
    !self.class.organization_kinds_authorized.include?(organization_kind)
  end

  def add_failed_claim_error(str_or_array)
    self.failed_claim_errors = [
      failed_claim_errors || nil,
      Array(str_or_array)
    ].flatten.compact.join(", ")
  end

  def safe_assign_creator_kind=(val)
    return unless CREATOR_KIND_ENUM.keys.map(&:to_s).include?(val.to_s)

    if val == "creator_bike_creation"
      set_creator_kind!
    else
      self.creator_kind = val
    end
  end

  def set_calculated_attributes
    self.creator_kind ||= "creator_user"
    self.organization_kind ||= calculated_organization_kind
    self.kind ||= calculated_kind
    self.update_number ||= previous_successful_updates.count + 1
  end

  def set_creator_kind!
    if bike&.current_ownership.present?
      self.organization_id ||= bike.current_ownership.organization_id
      self.creator_kind = "creator_pos" if bike.current_ownership.pos?
      if bike.current_ownership.bulk?
        self.creator_kind ||= "creator_import"
        self.bulk_import_id = bike.current_ownership.bulk_import_id
      end
    end
    self.creator_kind ||= "creator_bike_creation"
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
    return "un_claim" if bike.blank? && bike_id.blank?

    previous_successful_updates.any? ? "re_claim" : "initial_claim"
  end
end
