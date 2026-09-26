# The record that a registrant agreed to an organization's e-vehicle safety rules.
# Outlives the registration it came from - the b_param is swept once its bike exists.
# Pending (no acknowledged_at) from when the bike is created until they're agreed to.
# What was agreed to is read off the sequence, which activation froze.
# == Schema Information
#
# Table name: registration_sequence_acknowledgments
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  acknowledged_at          :datetime
#  owner_email              :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  b_param_id               :bigint
#  bike_id                  :bigint
#  registration_sequence_id :bigint
#  user_id                  :bigint
#
# Indexes
#
#  idx_on_registration_sequence_id_78f7372741                   (registration_sequence_id)
#  index_registration_sequence_acknowledgments_on_b_param_id    (b_param_id)
#  index_registration_sequence_acknowledgments_on_bike_id       (bike_id)
#  index_registration_sequence_acknowledgments_on_user_id       (user_id)
#  index_registration_sequence_acknowledgments_one_per_b_param  (b_param_id) UNIQUE WHERE (b_param_id IS NOT NULL)
#  index_registration_sequence_acknowledgments_pending          (b_param_id) WHERE (acknowledged_at IS NULL)
#
class RegistrationSequenceAcknowledgment < ApplicationRecord
  # with_deleted: the sequence is soft-deleted with its organization, and this record
  # reads what was agreed to straight off it
  belongs_to :registration_sequence, -> { with_deleted }
  belongs_to :b_param
  belongs_to :bike
  belongs_to :user

  # The unfinished_registration alert reads whether this is pending. Not on create: the
  # pending one is made just before its b_param saves the bike, which refreshes it anyway
  after_commit(on: %i[update destroy]) { b_param&.update_unfinished_registration_alerts }

  scope :pending, -> { where(acknowledged_at: nil) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }
  scope :for_organization, ->(organization) {
    joins(:registration_sequence).where(registration_sequences: {organization_id: organization})
  }

  class << self
    # The pages are acknowledged one at a time on the b_param; this is the moment they're
    # agreed to as a whole - onto the pending one when the bike came first, against the
    # sequence the pages were read from rather than the one it was pending on
    def acknowledge(b_param, sequence:, user: nil)
      acknowledgment = find_or_initialize_by(b_param_id: b_param.id)
      acknowledgment.update(registration_sequence: sequence, user_id: acknowledgment.user_id || user&.id,
        owner_email: b_param.owner_email, acknowledged_at: Time.current)
    end

    def create_pending(b_param, sequence:)
      create(registration_sequence: sequence, b_param:, owner_email: b_param.owner_email)
    end

    def find_for(bike:, organization:) = acknowledged.for_organization(organization).where(bike_id: bike.id).last

    def bikes_order(organization:, direction:)
      acknowledged_at = for_organization(organization)
        .where("registration_sequence_acknowledgments.bike_id = bikes.id")
        .select("MAX(registration_sequence_acknowledgments.acknowledged_at)")
      Arel.sql("(#{acknowledged_at.to_sql}) #{(direction == "asc") ? "ASC" : "DESC"}")
    end
  end

  # The review is only reachable with every page acknowledged, so the whole (frozen)
  # sequence is what was agreed to
  def acknowledged_pages
    registration_sequence&.registration_sequence_pages
  end

  def acknowledgment_text
    registration_sequence&.acknowledgment
  end
end
