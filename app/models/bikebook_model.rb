# frozen_string_literal: true

# A model in the Bike Book catalog's index, which BikebookModelsSyncJob copies here so that registering doesn't wait on
# the index, the catalog's biggest file. `variants` are its market variants' ids and markets, [{"id", "markets"}]
# == Schema Information
#
# Table name: bikebook_models
# Database name: primary
#
#  id                :bigint           not null, primary key
#  final_year        :integer
#  first_year        :integer          not null
#  manufacturer_slug :string           not null
#  markets           :string           default([]), not null, is an Array
#  model_slug        :string           not null
#  name              :string           not null
#  variants          :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  catalog_id        :string           not null
#
# Indexes
#
#  index_bikebook_models_on_catalog_id                        (catalog_id) UNIQUE
#  index_bikebook_models_on_manufacturer_slug_and_model_slug  (manufacturer_slug,model_slug)
#
class BikebookModel < ApplicationRecord
  scope :sold_in_year, ->(year) { where(first_year: ..year, final_year: [nil, year..]) }

  class << self
    # The catalog id of the manufacturer's model of that name sold in that year, nil for one the catalog lacks. Of
    # several, the one sold in `market`, a country's ISO code, then the latest
    def catalog_id_for(manufacturer:, name:, year:, market: nil)
      market = "EU" if EbikeRuleServices::Places::EU_MEMBERS.include?(market)
      models = where(manufacturer_slug: Slugifyer.manufacturer(manufacturer), model_slug: Slugifyer.book_slug(name))
        .sold_in_year(year).order(first_year: :desc, catalog_id: :asc).to_a
      (models.find { it.sold_in?(market) } || models.first)&.catalog_id_in(market)
    end

    # A page of the manufacturer's model names with every word of `query` in them, each name once
    def names_matching(manufacturer_slug, query, page:, per_page:)
      query.to_s.split.reduce(where(manufacturer_slug:)) { |models, word| models.where("name ILIKE ?", "%#{sanitize_sql_like(word)}%") }
        .distinct.order(:name).offset((page - 1) * per_page).limit(per_page).pluck(:name)
    end
  end

  def sold_in?(market) = [*markets, *variants.flat_map { it["markets"] }].include?(market)

  def catalog_id_in(market) = variants.find { it["markets"].include?(market) }&.dig("id") || catalog_id
end
