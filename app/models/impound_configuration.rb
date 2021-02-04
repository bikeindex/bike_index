class ImpoundConfiguration < ApplicationRecord
  belongs_to :organization
  has_many :impound_records, through: :organization

  validates :organization_id, presence: true, uniqueness: true

  before_validation :set_calculated_attributes

  # t.references :organization
  # t.boolean :public_view, default: false

  # t.integer :display_id_next_integer
  # t.string :display_id_prefix

  # Stub for now. Might actually just be public_impound_bikes?
  # use a separate model - impound_configuration
  def impound_claims?
    public_view?
  end

  def calculated_display_id_next
    "#{display_id_prefix}#{calculated_display_id_next_integer}"
  end

  def calculated_display_id_next_integer
    # display_id_next_integer input is validated - and in ProcessImpoundUpdatesWorker it's removed if it's been used
    return display_id_next_integer if display_id_next_integer.present?
    last_display_id_integer + 1
    # return default_display_id unless ImpoundRecord.where(organization_id: organization_id, display_id: default_display_id)
    # ImpoundRecord.where(organization_id: organization_id).maximum(:display_id).to_i + 1
  end

  def set_calculated_attributes
    self.display_id_prefix = nil if display_id_prefix.blank?
  end

  private

  def last_display_id_integer
    ImpoundRecord.where(organization_id: organization_id, display_id_prefix: display_id_prefix)
      .where.not(display_id_integer: nil).maximum(:display_id_integer) || 0
    # irs = irs.where("id < ?", id) if id.present?
    # irs.maximum(:display_id) || 0
  end
end
