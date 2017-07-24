class RecoveryDisplay < ActiveRecord::Base
  validates_presence_of :quote, :date_recovered
  mount_uploader :image, CircularImageUploader
  process_in_background :image, CarrierWaveProcessWorker
  belongs_to :stolen_record

  default_scope { order('date_recovered desc') }

  attr_accessor :date_input

  before_validation :set_time
  def set_time
    if date_input.present?
      self.date_recovered = DateTime.strptime("#{date_input} 06", '%m-%d-%Y %H')
    end
    self.date_recovered = Time.now unless date_recovered.present?
  end

  validate :quote_not_too_long
  def quote_not_too_long
    return true if quote.blank? || quote.length < 301
    errors.add :base, 'That quote is too long. Please shorten it to be less than 300 characters'
  end

  def from_stolen_record(sr_id)
    sr = StolenRecord.unscoped.where(id: sr_id).first
    return true unless sr.present?
    self.stolen_record_id = sr_id
    self.date_recovered = sr.date_recovered
    self.quote = sr.recovered_description
    self.quote_by = sr.bike.current_ownership && sr.bike.owner && sr.bike.owner.name
  end

  def bike
    return nil unless stolen_record_id.present?
    StolenRecord.unscoped.find(stolen_record_id).bike
  end
end
