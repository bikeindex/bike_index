# frozen_string_literal: true

module Integrations
  module Bikebook
    # Finds the catalog model a typed frame model names, by the slug BikebookModelsSyncJob stores each model under
    module ModelSearch
      extend Functionable

      # The manufacturer's model of that name sold in that year, nil for one the catalog lacks. Of several, the one sold in
      # `market`, a catalog market, then the latest
      def matching(manufacturer_id:, name:, year:, market: "US")
        models = BikebookModel.where(manufacturer_id:, model_slug: slug(name)).sold_in_year(year)
          .order(first_year: :desc, catalog_id: :asc).to_a
        models.find { it.markets.include?(market) } || models.first
      end

      # Keeps parenthesized text, which tells catalog models apart - eg Bianchi's "(SPECIFIC FOR ASIA)" builds
      def slug(name) = Slugifyer.slugify(Slugifyer.without_cycle_words(name).tr("()", " "))
    end
  end
end
