# frozen_string_literal: true

class AbandonedRecord < ActiveRecord::Base
  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :impounded_record
  belongs_to :initial_abandoned_record
  # has_many :repeat_abandoned_records

  validates_presence_of :bike_id, :user_id

  before_validation :set_calculated_attributes
  before_validation :validate_requirements_for_kind
  after_commit :update_associations

  scope :current, -> { where(retrieved_at: nil, impound_record_id: nil) }
  scope :initial_record, -> { where(initial_abandoned_record: nil) }
  scope :repeat_record, -> { where.not(initial_abandoned_record: nil) }
  scope :impounded, -> { where.not(impound_record_id: nil) }
  scope :retrieved, -> { where.not(retrieved_at: nil) }

  def current?; !retrieved? && !impounded? end

  def retrieved?; retrieved_at.present? end

  def impounded?; impound_record_id.present? end

  def initial_record?; initial_abandoned_record_id.blank? end

  def repeat_record?; initial_abandoned_record_id.present? end

  def owner_known?
    bike.present? && bike.created_at < (Time.current - 1.day)
  end

  def mark_retrieved
    update_attributes(retrieved_at: Time.current) if current?
  end

  def update_associations
    # repeat_abandoned_records.map(&:update)
    bike&.update_attributes(updated_at: Time.current)
  end
end
