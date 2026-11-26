# frozen_string_literal: true

# The Bike Book model a Bike or BikeVersion was registered as
# == Schema Information
#
# Table name: vehicle_specifications
# Database name: primary
#
#  id                :bigint           not null, primary key
#  bike_obj_type     :string           not null
#  bikebook_market   :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  bike_obj_id       :bigint           not null
#  bikebook_model_id :bigint
#
# Indexes
#
#  index_vehicle_specifications_on_bike_obj           (bike_obj_type,bike_obj_id) UNIQUE
#  index_vehicle_specifications_on_bikebook_model_id  (bikebook_model_id)
#
class VehicleSpecification < ApplicationRecord
  belongs_to :bike_obj, polymorphic: true
  belongs_to :bikebook_model, -> { with_deleted }
end
