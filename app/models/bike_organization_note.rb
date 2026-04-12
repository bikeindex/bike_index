# frozen_string_literal: true

# == Schema Information
#
# Table name: bike_organization_notes
# Database name: primary
#
#  id              :bigint           not null, primary key
#  body            :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  bike_id         :bigint           not null
#  organization_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_bike_organization_notes_on_bike_id_and_organization_id  (bike_id,organization_id) UNIQUE
#  index_bike_organization_notes_on_organization_id              (organization_id)
#  index_bike_organization_notes_on_user_id                      (user_id)
#
class BikeOrganizationNote < ApplicationRecord
  has_paper_trail only: %i[bike_id body]

  belongs_to :bike
  belongs_to :organization
  belongs_to :user

  validates_presence_of :bike_id, :organization_id, :user_id

  before_save :set_calculated_attributes

  def self.upsert(bike:, organization:, body:, user:)
    note = find_or_initialize_by(bike_id: bike.id, organization_id: organization.id)
    note.update!(body:, user:)
  end

  private

  def set_calculated_attributes
    self.body = body&.strip.presence
  end
end
