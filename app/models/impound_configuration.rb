# == Schema Information
#
# Table name: impound_configurations
#
#  id                      :bigint           not null, primary key
#  bulk_import_view        :boolean          default(FALSE)
#  display_id_next_integer :integer
#  display_id_prefix       :string
#  email                   :string
#  expiration_period_days  :integer
#  public_view             :boolean          default(FALSE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :bigint
#
# Indexes
#
#  index_impound_configurations_on_organization_id  (organization_id)
#
class ImpoundConfiguration < ApplicationRecord
  belongs_to :organization
  has_many :impound_records, through: :organization

  validates :organization_id, presence: true, uniqueness: true

  before_validation :set_calculated_attributes

  after_commit :update_organization

  scope :expiration, -> { where.not(expiration_period_days: nil) }

  def expiration?
    expiration_period_days.present?
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
    self.expiration_period_days = nil unless expiration_period_days.present? && expiration_period_days > 0
    unless bulk_import_view
      self.bulk_import_view = false # should set based off whether there are any bulk imports, and not turn off once on
    end
  end

  # Bump organization to update enabled slugs
  def update_organization
    organization&.update(updated_at: Time.current)
  end

  def expired_before
    Time.current - expiration_period_days.days
  end

  def impound_records_to_expire
    return ImpoundRecord.none unless expiration?
    impound_records.active.where("impound_records.created_at < ?", expired_before)
  end

  private

  def last_display_id_integer
    ImpoundRecord.where(organization_id: organization_id, display_id_prefix: display_id_prefix)
      .where.not(display_id_integer: nil).maximum(:display_id_integer) || 0
  end
end
