# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      # The catalog search and comparison, rendered in the browser from the published catalog.
      # The page is a <template> bikebook--page fills in from the URL and the catalog,
      # and renders again for each pick and history step
      class Component < ApplicationComponent
        # market is the visitor's CF-IPCountry, which Cloudflare sends as XX, or T1 over Tor, when it can't
        # tell; state is theirs in the US. framed: in an iframe, whose autofocus would take its host page's focus
        def initialize(manifest_url:, market:, state:, query:, paint_colors:, framed: false)
          @manifest_url = manifest_url
          @framed = framed
          @paint_colors = paint_colors
          @market = (%w[XX T1].include?(market) || market.blank?) ? "US" : Integrations::Bikebook::Catalog.market(market)
          @jurisdiction = state&.dig(:abbr) || "US"
          @query = query
        end

        private

        # The state laws are all the markup reads that its code doesn't, so the fragments keep until either changes, and
        # aren't kept while the catalog doesn't answer, rendering without them
        def catalog_version = @catalog_version ||= EbikeRuleServices::StateLaws.version

        # Every visitor's and every query's, which bikebook--page and placeholder_class fill in around them
        def page_cache_key(*parts) = child_cache_key(self.class, *parts)

        # A component's own fragment inside the page's, under skip_digest: Rails' digest of this template would expire it
        # with any change here. Not cache_on: these also render on /ebike-rules, where the same tile twice would repeat
        # its tooltip's id
        def child_cache_key(component, *parts) = [component.cache_digest, 2, catalog_version, *parts]

        # The search until bikebook--page fills it in from the URL: hidden as searching() hides a lone model's, and blank
        # where the URL sets anything but picks, which it says are loading
        def placeholder_class
          models = Integrations::Bikebook::Catalog.vehicle_entries(@query["vehicle_models"]).map { Integrations::Bikebook::Catalog.vehicle_id(it) }.compact_blank
          classifications = @query["classifications"].to_s.split(",").compact_blank
          return "tw:hidden" if models.one? && classifications.none? && !@query.key?("search")
          "tw:invisible" if @query.except("search", "vehicle_models").any?
        end

        # The pins preloaded for the bikebook entry point, without the application's that the layout preloads
        def module_preloads
          packages = Rails.application.importmap.preloaded_module_packages(resolver: helpers, entry_point: "bikebook", cache_key: "bikebook")
          helpers.javascript_module_preload_tag(*packages.filter_map { |path, package| path if package.preload == "bikebook" })
        end

        # Saying so until the catalog loads, which the search waits on, like loadingShell's. Swapped rather than rendered
        # again for the one attribute, as the search is a third of the page's render
        def placeholder_search(search)
          search.sub(%(placeholder="#{h(translation(".search_placeholder"))}"), %(placeholder="#{h(translation(".loading_placeholder"))}")).html_safe
        end

        # The closed filters' and the open card's, so it's beside whichever shows
        def more_filters = render(UI::Collapse::Component.new(text: translation(".more_filters"), chevron: true,
          color: :link, html_class: "tw:ml-auto", aria: {controls: "vehicle-filters"}))

        # How the market narrows the search, preferring it - the blank default - unless only it or any will do. Named by
        # bikebook--page for the visitor's, then by bikebook--catalog-filters for the one picked
        def market_scopes
          market = tag.span(data: {"bikebook--catalog-filters-target": "marketName"})
          [{value: "", label: translation(".prefer_market_sold_in_html", market:)}, {value: "only", label: translation(".only_market_html", market:)},
            {value: "any", label: translation(".any_market")}]
        end

        # By the ISO 3166-2 codes the catalog's classifications name their jurisdictions by
        def jurisdiction_names = {"US" => translation(".united_states")}
          .merge(EbikeRuleServices::StateLaws::STATES.to_h { ["US-#{it[:abbr]}", it[:name]] })

        # The US classes, then the states' own, which /ebike-rules shows too; a state without them uses the US ones
        def class_groups
          us = [{id: "class-1", name: translation(".us_class_1")}, {id: "class-2", name: translation(".us_class_2")},
            {id: "class-3", name: translation(".us_class_3")}, EbikeRuleServices::StateLaws::NOT_AN_EBIKE]
          {"US" => us}.merge(EbikeRuleServices::StateLaws.own_classes)
        end
      end
    end
  end
end
