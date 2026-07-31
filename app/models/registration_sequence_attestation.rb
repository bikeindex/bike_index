# The record that a registrant agreed to an organization's e-vehicle safety rules.
# Outlives the registration it came from - the b_param is swept once its bike exists.
# What was agreed to is read off the sequence, which activation froze.
# == Schema Information
#
# Table name: registration_sequence_attestations
# Database name: primary
#
#  id                       :bigint           not null, primary key
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
#  idx_on_registration_sequence_id_fa88640992                (registration_sequence_id)
#  index_registration_sequence_attestations_on_b_param_id    (b_param_id)
#  index_registration_sequence_attestations_on_bike_id       (bike_id)
#  index_registration_sequence_attestations_on_user_id       (user_id)
#  index_registration_sequence_attestations_one_per_b_param  (b_param_id) UNIQUE WHERE (b_param_id IS NOT NULL)
#
class RegistrationSequenceAttestation < ApplicationRecord
  # with_deleted: the sequence is soft-deleted with its organization, and this record
  # reads what was agreed to straight off it
  belongs_to :registration_sequence, -> { with_deleted }
  belongs_to :b_param
  belongs_to :bike
  belongs_to :user

  scope :for_organization, ->(organization) {
    joins(:registration_sequence).where(registration_sequences: {organization_id: organization})
  }

  class << self
    # The pages are acknowledged one at a time on the b_param; this is the moment
    # they're agreed to as a whole
    def create_for(b_param, sequence:, user: nil)
      create(registration_sequence: sequence, b_param:, user:, owner_email: b_param.owner_email)
    end
  end

  def attested_at = created_at

  # The review is only reachable with every page acknowledged, so the whole (frozen)
  # sequence is what was agreed to
  def acknowledged_pages
    registration_sequence&.registration_sequence_pages
  end

  def attestation_text
    registration_sequence&.attestation
  end
end
