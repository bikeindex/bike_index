# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCitiesEducation
      # The e-bike education flow as example organizations would set it up, rendered
      # through the registration flow's own acknowledgment parts
      class Component < ApplicationComponent
        DEFAULT_ORGANIZATION = :school
        # Here rather than on the cities page, which would put that page in this cached fragment's digest
        PANEL_CLASSES = "tw:scroll-mt-24 tw:[grid-area:1/1] tw:focus:outline-none"
        STICKER_CLASSES = "tw:flex tw:items-center tw:gap-4 tw:rounded-lg tw:border-3 tw:border-black tw:bg-white tw:px-5 tw:py-4.5 tw:shadow-[4px_4px_0_#111] tw:dark:bg-gray-800"

        private

        def organizations = @organizations ||= build_organizations

        # The city's programs carry its pages, each adding a page of its own
        def build_organizations
          city = sequence(translation(".city_name"))
          city_pages = pages(city, [battery, city_riding, city_rules])
          school = sequence(translation(".school_name"), translation(".school_tab"))
          housing = sequence(translation(".housing_name"), translation(".housing_tab"))
          riverside = sequence(translation(".riverside_name"), translation(".riverside_tab"))
          [
            {key: :city, blurb: translation(".city_blurb"), sequence: city, pages: city_pages},
            {key: :school, blurb: translation(".school_campus_blurb"), sequence: school, pages: city_pages + pages(school, [school_rules])},
            {key: :housing, blurb: translation(".housing_building_blurb"), sequence: housing, pages: city_pages + pages(housing, [housing_rules])},
            {key: :riverside, blurb: translation(".riverside_blurb"), sequence: riverside, pages: city_pages + pages(riverside, [riverside_rules])}
          ]
        end

        # Unsaved - an example to render, not one to keep
        def sequence(name, short_name = name) = RegistrationSequence.new(organization: Organization.new(name:, short_name:))

        def pages(sequence, attributes) = attributes.map { RegistrationSequencePage.new(registration_sequence: sequence, **it) }

        def page(title:, rules:, subtitle: nil, heading: nil, organization_specific: false)
          {title:, heading:, subtitle:, organization_specific:, body: tag.ul(safe_join(rules.map { tag.li(it) })).to_s}
        end

        def battery
          page(title: translation(".battery_category"), heading: translation(".battery_title"), subtitle: translation(".city_battery_sub"),
            rules: [translation(".battery_rule_charger"), translation(".battery_rule_unattended"), translation(".battery_rule_flammable")])
        end

        def city_riding
          page(title: translation(".riding_category"), subtitle: translation(".city_riding_sub"),
            rules: [translation(".city_riding_rule_helmet"), translation(".city_riding_rule_lanes"), translation(".city_riding_rule_sidewalks")])
        end

        def city_rules
          page(title: translation(".city_rules_category"), heading: translation(".city_rules_title"), subtitle: translation(".city_rules_sub"),
            organization_specific: true,
            rules: [translation(".city_rule_class_3"), translation(".city_rule_parking"), translation(".city_rule_classes")])
        end

        def school_rules
          page(title: translation(".school_rules_category"), heading: translation(".school_rules_title"), subtitle: translation(".school_rules_sub"),
            organization_specific: true,
            rules: [translation(".school_rule_class_1"), translation(".school_rule_walk"), translation(".school_rule_traffic"), translation(".school_rule_guardian")])
        end

        def housing_rules
          page(title: translation(".housing_rules_category"), heading: translation(".housing_rules_title"), subtitle: translation(".housing_rules_sub"),
            organization_specific: true, rules: [translation(".housing_rule_storage"), translation(".housing_rule_sticker")])
        end

        def riverside_rules
          page(title: translation(".riverside_rules_category"), organization_specific: true,
            rules: [translation(".riverside_rule_parking"), translation(".riverside_rule_charging")])
        end

        def back_button
          tag.div(class: "tw:mt-3 tw:text-center") do
            render(UI::Button::Component.new(color: :link, html_class: "tw:text-sm tw:text-gray-600", data: {action: "landing-pages--education#back"})) do
              safe_join([tag.span("←", aria: {hidden: true}), translation(".back")], " ")
            end
          end
        end
      end
    end
  end
end
