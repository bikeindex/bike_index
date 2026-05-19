# frozen_string_literal: true

module Search
  module EverythingCombobox
    module Options
      # Renders the turbo-stream of autocomplete options for the search query
      # items combobox - reproduces the option formatting the field used under
      # select2. Sibling to Search::EverythingCombobox::Component (the form
      # control); this is the async response that backs its autocomplete.
      class Component < ApplicationComponent
        def initialize(matches:, search_obj_name:, next_page:)
          @matches = matches
          @search_obj_name = search_obj_name
          @next_page = next_page
        end

        def call
          helpers.hw_async_combobox_options(option_data, next_page: @next_page)
        end

        private

        def option_data
          @matches.map do |match|
            {
              id: match["search_id"],
              value: match["search_id"],
              display: match["text"],
              content: option_content(match)
            }
          end
        end

        def option_content(match)
          text = match["text"].to_s

          case match["category"]
          when "propulsion"
            tag.span safe_join([translation(".search_for"), " ", tag.strong(text), " only"])
          when "cycle_type"
            tag.span safe_join([translation(".search_only_for"), " ", tag.strong(text)])
          else
            safe_join([option_prefix(match), " ", tag.span(text, class: "label")])
          end
        end

        def option_prefix(match)
          case match["category"]
          when "colors"
            prefix = tag.span("#{@search_obj_name} #{translation(".that_are")} ", class: "sch_")
            swatch = if match["display"].present?
              tag.span("", class: "sclr", style: "background: #{match["display"]}")
            else
              tag.span("stckrs", class: "sclr")
            end
            safe_join([prefix, swatch])
          when "cmp_mnfg", "frame_mnfg"
            tag.span("#{@search_obj_name} #{translation(".made_by")}", class: "sch_")
          else
            translation(".search_for")
          end
        end

        # Use the sibling Search::EverythingCombobox::Component's i18n scope
        # so both render with the same strings (no duplicate keys to maintain)
        def translation(key)
          I18n.t(key.delete_prefix("."), scope: "components.search.everything_combobox")
        end
      end
    end
  end
end
