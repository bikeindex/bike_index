# frozen_string_literal: true

# == Schema Information
#
# Table name: bikebook_models
# Database name: primary
#
#  id              :bigint           not null, primary key
#  data            :jsonb
#  data_file       :string
#  deleted_at      :datetime
#  final_year      :integer
#  first_year      :integer          not null
#  markets         :string           default([]), not null, is an Array
#  model_slug      :string           not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  catalog_id      :string           not null
#  manufacturer_id :bigint           not null
#
# Indexes
#
#  index_bikebook_models_on_catalog_id                      (catalog_id) UNIQUE
#  index_bikebook_models_on_manufacturer_id_and_model_slug  (manufacturer_id,model_slug)
#
# A model in the Bike Book catalog's index, which BikebookModelsSyncJob copies here so that registering doesn't wait on
# the index, the catalog's biggest file. `markets` are every market it's sold in, its market variants' too. `data` is
# the records of the model and its market variants by citation key, which BikebookModelsSyncJob copies from
# `data_file`, the model's block
class BikebookModel < ApplicationRecord
  acts_as_paranoid

  belongs_to :manufacturer

  scope :sold_in_year, ->(year) { where(first_year: ..year, final_year: [nil, year..]) }

  # The name of a catalog id or a market variant's citation key (…/haul-st@CA), which a pick in registration's model
  # combobox submits. Anything else, typed rather than picked, as it is
  def self.frame_model(value)
    (where(catalog_id: Integrations::Bikebook::Catalog.base_id(value)).pick(:name) if value.to_s.match?(Integrations::Bikebook::Catalog::MODEL_ID)) || value
  end

  # The model's record with its `market`'s variant laid over it
  def market_data(market: nil)
    market ||= "US"
    data&.then { it[catalog_id]&.merge(it["#{catalog_id}@#{market}"].to_h) }
  end
end
