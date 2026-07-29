# The record that a registrant agreed to an organization's e-vehicle safety rules.
# Outlives the registration it came from - the b_param is swept once its bike exists,
# and the sequence's text is snapshotted here, so this stands on its own.
# == Schema Information
#
# Table name: registration_sequence_attestations
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  acknowledged_page_ids    :bigint           default([]), is an Array
#  attestation_text         :text
#  attested_at              :datetime         not null
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
  belongs_to :registration_sequence
  belongs_to :b_param
  belongs_to :bike
  belongs_to :user

  validates :attested_at, presence: true

  scope :for_organization, ->(organization) {
    joins(:registration_sequence).where(registration_sequences: {organization_id: organization})
  }

  class << self
    # The pages are acknowledged one at a time on the b_param; this is the moment
    # they're agreed to as a whole
    def create_for(b_param, sequence:, page_ids:, user: nil)
      create(registration_sequence: sequence, b_param:, user:, owner_email: b_param.owner_email,
        acknowledged_page_ids: page_ids, attestation_text: sequence.attestation,
        attested_at: Time.current)
    end
  end

  # Nil once the sequence is gone - attestation_text is what survives that
  def acknowledged_pages
    registration_sequence&.registration_sequence_pages&.where(id: acknowledged_page_ids)
  end
end
