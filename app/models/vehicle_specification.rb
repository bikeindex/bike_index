# frozen_string_literal: true

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
# The Bike Book model a Bike or BikeVersion was registered as
class VehicleSpecification < ApplicationRecord
  belongs_to :bike_obj, polymorphic: true
  belongs_to :bikebook_model, -> { with_deleted }

  # Unsaved: a catalog id's or citation key's model, in the market after its @, else `market`. nil for one not synced
  def self.cited(bikebook_id, market: "US", bikebook_models: BikebookModel)
    return if bikebook_id.blank?

    bikebook_models.find_by(catalog_id: Integrations::Bikebook::Catalog.base_id(bikebook_id))
      &.then { new(bikebook_model: it, bikebook_market: bikebook_id[Integrations::Bikebook::Catalog::MARKET, 1] || market) }
  end

  # The citation key of the model in its market, which a b_param's bikebook_model holds
  def bikebook_id = bikebook_model&.then { "#{it.catalog_id}@#{bikebook_market}" }

  def bikebook_data = bikebook_model&.market_data(market: bikebook_market)

  def bikebook_data_bike_attributes(year: bike_obj.year) = bikebook_data&.then { Integrations::Bikebook::Data.bike_attributes(it, year) }

  def bikebook_data_component_attributes = bikebook_data&.then { Integrations::Bikebook::Data.component_attributes(it) }
end
