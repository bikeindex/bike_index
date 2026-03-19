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
#  index_bike_organization_notes_on_bike_id                      (bike_id)
#  index_bike_organization_notes_on_bike_id_and_organization_id  (bike_id,organization_id) UNIQUE
#  index_bike_organization_notes_on_organization_id              (organization_id)
#  index_bike_organization_notes_on_user_id                      (user_id)
#
class BikeOrganizationNote < ApplicationRecord
  has_paper_trail only: %i[body user_id]

  belongs_to :bike
  belongs_to :organization
  belongs_to :user

  validates :body, presence: true

  def self.upsert_or_delete(bike:, organization:, body:, user:)
    body = body.to_s&.strip
    existing = find_by(bike_id: bike.id, organization_id: organization.id)
    if body.present?
      note = existing || new(bike:, organization:)
      note.update!(body:, user:)
    elsif existing.present?
      existing.destroy!
    end
  end
end
