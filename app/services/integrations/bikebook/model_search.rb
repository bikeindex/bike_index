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

      # Drops "bike", "e-bike", "bicycle" and the like, which people put in everything
      def slug(name)
        I18n.transliterate(name.to_s.downcase).strip
          .gsub("%20", " ")
          .gsub(/\s(e(lectric)?.?)?((bi)?cycles?|bikes?)/i, " ")
          .gsub("+", "plus").gsub("&", "amp")
          .gsub(/[^a-z0-9]/i, " ")
          .split.join("_")
      end
    end
  end
end
