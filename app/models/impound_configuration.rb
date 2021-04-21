class ImpoundConfiguration < ApplicationRecord
  belongs_to :organization
  has_many :impound_records, through: :organization

  validates :organization_id, presence: true, uniqueness: true

  before_validation :set_calculated_attributes

  # Stub for now, because it might be more sophisticated later
  def impound_claims?
    public_view?
  end

  # May do something different in the future
  def previous_prefixes
    organization.impound_records.distinct.pluck(:display_id_prefix).reject(&:blank?)
  end

  def calculated_display_id_next
    "#{display_id_prefix}#{calculated_display_id_next_integer}"
  end

  def calculated_display_id_next_integer
    # TODO: display_id_next_integer input needs to be validated
    # currently, in ProcessImpoundUpdatesWorker it's removed if it's been used
    return display_id_next_integer if display_id_next_integer.present?
    last_display_id_integer + 1
  end

  def set_calculated_attributes
    self.display_id_prefix = nil if display_id_prefix.blank?
    self.email = nil if email.blank?
    unless bulk_import_view
      self.bulk_import_view = false # should set based off whether there are any bulk imports, and not turn off once on
    end
  end

  private

  def last_display_id_integer
    ImpoundRecord.where(organization_id: organization_id, display_id_prefix: display_id_prefix)
      .where.not(display_id_integer: nil).maximum(:display_id_integer) || 0
  end
end
