# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCitiesEducation
      # The e-bike education flow as three example organizations would set it up. Every step renders,
      # and the landing-pages--education controller walks through them
      class Component < ApplicationComponent
        DEFAULT_ORGANIZATION = :school

        private

        def organizations
          city = translation(".city_name")
          school = translation(".school_name")
          housing = translation(".housing_name")
          [
            {key: :city, tab: city, name: city, blurb: translation(".city_blurb"),
             steps: [battery(city, translation(".city_battery_sub")), city_riding(city), city_rules(city), consent(city)]},
            {key: :school, tab: translation(".school_tab"), name: school, blurb: translation(".school_blurb"),
             steps: [battery(city, translation(".school_battery_sub")), school_riding(school), school_rules(school), consent(school)]},
            {key: :housing, tab: translation(".housing_tab"), name: housing, blurb: translation(".housing_blurb"),
             steps: [housing_battery(housing), city_riding(city), housing_rules(housing), consent(housing)]}
          ]
        end

        def battery(set_by, sub)
          {category: translation(".battery_category"), title: translation(".battery_title"), sub:, set_by:, detected: true,
           rules: [translation(".battery_rule_charger"), translation(".battery_rule_unattended"), translation(".battery_rule_flammable")]}
        end

        def housing_battery(set_by)
          {category: translation(".battery_category"), title: translation(".battery_title"), sub: translation(".housing_battery_sub"),
           set_by:, detected: true,
           rules: [translation(".housing_battery_rule_room"), translation(".housing_battery_rule_certified"), translation(".housing_battery_rule_report")]}
        end

        def city_riding(set_by)
          {category: translation(".riding_category"), title: translation(".riding_category"), sub: translation(".city_riding_sub"), set_by:,
           rules: [translation(".city_riding_rule_helmet"), translation(".city_riding_rule_lanes"), translation(".city_riding_rule_sidewalks")]}
        end

        def school_riding(set_by)
          {category: translation(".riding_category"), title: translation(".riding_category"), sub: translation(".school_riding_sub"), set_by:,
           rules: [translation(".school_riding_rule_helmet"), translation(".school_riding_rule_passenger"),
             translation(".school_riding_rule_traffic"), translation(".school_riding_rule_guardian")]}
        end

        def city_rules(set_by)
          {category: translation(".city_rules_category"), title: translation(".city_rules_title"), sub: translation(".city_rules_sub"),
           set_by:, organization_badge: true,
           rules: [translation(".city_rule_class_3"), translation(".city_rule_parking"), translation(".city_rule_classes")]}
        end

        def school_rules(set_by)
          {category: translation(".school_rules_category"), title: translation(".school_rules_title"), sub: translation(".school_rules_sub"),
           set_by:, organization_badge: true,
           rules: [translation(".school_rule_class_1"), translation(".school_rule_walk")]}
        end

        def housing_rules(set_by)
          {category: translation(".housing_rules_category"), title: translation(".housing_rules_title"), sub: translation(".housing_rules_sub"),
           set_by:, organization_badge: true,
           rules: [translation(".housing_rule_storage"), translation(".housing_rule_sticker")]}
        end

        def consent(name)
          {category: translation(".consent_category"), title: translation(".consent_title"), sub: translation(".consent_sub", name:),
           set_by: translation(".bike_index"), rules: [translation(".consent_rule_read"), translation(".consent_rule_agree")]}
        end

        # Each step renders its own, so walking through the steps needs no script to fill it
        def progress(filled:, total:, label:)
          bar = tag.div(class: "tw:mb-3 tw:grid tw:grid-flow-col tw:auto-cols-fr tw:gap-1.5", aria: {hidden: true}) do
            safe_join((1..total).map { tag.span(class: "tw:h-1.25 tw:rounded-sm #{(it <= filled) ? "tw:bg-purple-500" : "tw:bg-gray-200 tw:dark:bg-gray-700"}") })
          end
          bar + tag.div(class: "tw:mb-4.5 tw:text-[13px] tw:font-semibold tw:text-gray-600 tw:dark:text-gray-400") do
            helpers.inline_svg_tag("icons/check.svg", class: "tw:inline tw:size-3.5 tw:stroke-3 tw:align-[-2px] tw:text-[#2e8b57]", aria_hidden: true) +
              " " + translation(".progress_saved_html", label:)
          end
        end

        def rule_count(organization) = organization[:steps].sum { it[:rules].size }
      end
    end
  end
end
