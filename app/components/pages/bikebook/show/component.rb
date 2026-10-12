# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      # The catalog search and comparison, rendered in the browser from the published catalog.
      # The page is a <template> bikebook--page fills in from the URL and the catalog,
      # and renders again for each pick and history step
      class Component < ApplicationComponent
        def initialize(manifest_url:)
          @manifest_url = manifest_url
        end

        private

        # By the ISO 3166-2 codes the catalog's classifications name their jurisdictions by
        def jurisdiction_names = {"US" => translation(".united_states")}
          .merge(EbikeRuleServices::StateLaws::STATES.to_h { ["US-#{it[:abbr]}", it[:name]] })

        def jurisdiction_options = jurisdiction_names.map { |code, name| [name, (code unless code == "US").to_s] }

        # The US classes, then the states' own, which /ebike-rules shows too; a state without them uses the US ones
        def class_groups
          us = [{id: "class_1", name: translation(".us_class_1")}, {id: "class_2", name: translation(".us_class_2")},
            {id: "class_3", name: translation(".us_class_3")}, EbikeRuleServices::StateLaws::NOT_AN_EBIKE]
          {"US" => us}.merge(EbikeRuleServices::StateLaws.own_classes.transform_keys { "US-#{it}" })
        end
      end
    end
  end
end
