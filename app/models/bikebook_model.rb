# frozen_string_literal: true

# A model in the Bike Book catalog's index, which BikebookModelsSyncJob copies here so that registering doesn't wait on
# the index, the catalog's biggest file. `market_variants` are the markets with a version of their own, each at
# catalog_id@market (…/haul-st@CA) - the index calls them variants, which Bike Book's schema uses for a colorway's SKUs
# == Schema Information
#
# Table name: bikebook_models
# Database name: primary
#
#  id              :bigint           not null, primary key
#  final_year      :integer
#  first_year      :integer          not null
#  market_variants :string           default([]), not null, is an Array
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
  # several, the one sold in `market`, a country's ISO code (the US when it's unknown), then the latest
  def self.catalog_id_for(manufacturer_id:, name:, year:, market: nil)
    market = Integrations::Bikebook::Catalog.market(market.presence || "US")
    models = where(manufacturer_id:, model_slug: Slugifyer.book_slug(name)).sold_in_year(year).order(first_year: :desc, catalog_id: :asc).to_a
    (models.find { it.sold_in?(market) } || models.first)&.catalog_id_in(market)
  end

  # The name of a catalog id or a market variant's citation key (…/haul-st@CA), which a pick in registration's model
  # combobox submits. Anything else, typed rather than picked, as it is
  def self.frame_model(value)
    id = value.to_s.sub(/@[A-Z]+\z/, "")
    (find_by(catalog_id: id)&.name if id.match?(Integrations::Bikebook::Catalog::MODEL_ID)) || value
  end

  def sold_in?(market) = [*markets, *market_variants].include?(market)

  def catalog_id_in(market) = market_variants.include?(market) ? "#{catalog_id}@#{market}" : catalog_id
end
