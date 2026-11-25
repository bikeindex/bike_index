# frozen_string_literal: true

# A model in the Bike Book catalog's index, which BikebookModelsSyncJob copies here so that registering doesn't wait on
# the index, the catalog's biggest file
# == Schema Information
#
# Table name: bikebook_models
# Database name: primary
#
#  id              :bigint           not null, primary key
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
class BikebookModel < ApplicationRecord
  belongs_to :manufacturer

  scope :sold_in_year, ->(year) { where(first_year: ..year, final_year: [nil, year..]) }

  # The catalog id of the manufacturer's model of that name sold in that year, nil for one the catalog lacks. Of
  # several, the one sold in `market`, a catalog market, then the latest
  def self.catalog_id_for(manufacturer_id:, name:, year:, market: "US")
    models = where(manufacturer_id:, model_slug: Slugifyer.book_slug(name)).sold_in_year(year).order(first_year: :desc, catalog_id: :asc).to_a
    (models.find { it.markets.include?(market) } || models.first)&.catalog_id
  end

  # The name of a catalog id or a market variant's citation key (…/haul-st@CA), which a pick in registration's model
  # combobox submits. Anything else, typed rather than picked, as it is
  def self.frame_model(value)
    id = value.to_s.sub(/@[A-Z]+\z/, "")
    (find_by(catalog_id: id)&.name if id.match?(Integrations::Bikebook::Catalog::MODEL_ID)) || value
  end
end
