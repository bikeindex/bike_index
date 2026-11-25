# frozen_string_literal: true

# The Bike Book model a vehicle was registered as. bikebook_model goes nil when BikebookModelsSyncJob deletes one the
# catalog drops
# == Schema Information
#
# Table name: vehicle_specifications
# Database name: primary
#
#  id                :bigint           not null, primary key
#  bikebook_market   :string
#  vehicle_type      :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  bikebook_model_id :bigint
#  vehicle_id        :bigint           not null
#
# Indexes
#
#  index_vehicle_specifications_on_bikebook_model_id  (bikebook_model_id)
#  index_vehicle_specifications_on_vehicle            (vehicle_type,vehicle_id) UNIQUE
#
class VehicleSpecification < ApplicationRecord
  belongs_to :vehicle, polymorphic: true
  belongs_to :bikebook_model
end
