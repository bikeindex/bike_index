# frozen_string_literal: true

# == Schema Information
#
# Table name: bike_organization_notes
# Database name: primary
#
#  id                   :bigint           not null, primary key
#  body                 :text
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  bike_organization_id :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_bike_organization_notes_on_bike_organization_id  (bike_organization_id) UNIQUE
#  index_bike_organization_notes_on_user_id               (user_id)
#
class BikeOrganizationNote < ApplicationRecord
  belongs_to :bike_organization
  belongs_to :user

  validates :body, presence: true
end
