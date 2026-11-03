# frozen_string_literal: true

module Pages
  module EbikeRules
    module StateReference
      # Template Dependency: SharedBlocks::Marketing::Wrapper::Component
      # Rendered whole, so search engines read the collapsed rules too. The US's states, or another checked country's
      # regions, each under the law a bike's checked against there
      class Component < ApplicationComponent
        # Open, a state's row becomes a card across the whole grid
        STATE_CLASSES = "tw:border-b tw:border-gray-200 tw:dark:border-gray-700 tw:has-[[aria-expanded=true]]:col-span-full " \
          "tw:has-[[aria-expanded=true]]:my-4 tw:has-[[aria-expanded=true]]:rounded-lg tw:has-[[aria-expanded=true]]:border " \
          "tw:has-[[aria-expanded=true]]:bg-white " \
          "tw:has-[[aria-expanded=true]]:shadow-[0_10px_30px_rgba(44,62,80,.12)] tw:dark:has-[[aria-expanded=true]]:bg-gray-800"

        def initialize(country: "US")
          @country = country
        end

        private

        def us? = @country == "US"

        # A republished vocabulary has a new file name, and a law's dated rules move on each day
        def cache_key = [self.class.cache_digest, @country, Integrations::Bikebook::Catalog.manifest&.dig("vocabulary"), Time.zone.today]

        def states
          @states ||= if us?
            laws = EbikeRuleServices::StateLaws.laws
            EbikeRuleServices::Places.us_states.map { it.merge(id: it[:abbr].downcase, law: laws[it[:abbr]]) }
          else
            laws = EbikeRuleServices::StateLaws.place_laws
            EbikeRuleServices::Places.regions(@country).map { it.merge(id: it[:code].downcase, law: laws[it[:code]]) }
          end
        end

        def on_file = states.count { it[:law] }

        def class_system(law)
          classes = law[:classes]
          return translation(".not_three_classes") if classes.none?

          translation(".only_classes", count: classes.size, classes: classes.join(" & "))
        end

        def copy
          @copy ||= if us?
            {heading: translation(".heading"), limits_subheading: translation(".limits_subheading"),
             filter_states: translation(".filter_states"), filter_placeholder: translation(".filter_placeholder"),
             no_match: translation(".no_match"), all_on_file: translation(".all_on_file"),
             on_file_of_total: translation(".on_file_of_total_html", number: number_display(on_file), total: states.size)}
          else
            {heading: translation(".heading_canada"), limits_subheading: translation(".limits_subheading_canada"),
             filter_states: translation(".filter_provinces"), filter_placeholder: translation(".filter_placeholder_canada"),
             no_match: translation(".no_match_canada"), all_on_file: translation(".all_on_file_canada"),
             on_file_of_total: translation(".on_file_of_total_canada_html", number: number_display(on_file), total: states.size)}
          end
        end

        def compiling(state) = us? ? translation(".compiling", state: state[:name]) : translation(".compiling_canada", state: state[:name])
      end
    end
  end
end
