# frozen_string_literal: true

module Org
  module SearchResults
    module MultiResultChip
      class Component < ApplicationComponent
        def initialize(chip_id:, result_count:, label:, search_kind: "serials", error: false, error_message: nil)
          @chip_id = chip_id
          @result_count = result_count
          @label = label
          @search_kind = search_kind
          @error = error
          @error_message = error_message
        end

        def call
          content_tag(:span, id: @chip_id, class: badge_classes) do
            if has_results?
              link_to(label_atom(html_class: link_text_classes), "#result_#{@chip_id.delete_prefix("chip_")}", class: "tw:py-1 tw:px-2")
            else
              label_atom + trailing_label
            end
          end
        end

        private

        def label_atom(html_class: nil)
          return render(Atom::Sticker::Component.new(pretty_code: @label, html_class:)) if sticker_search?

          render(Atom::Serial::Component.new(serial: @label, html_class:))
        end

        def sticker_search?
          @search_kind == "stickers"
        end

        def trailing_label
          label = content_tag(:small, @error ? "error" : translation(".no_results"), class: "tw:block tw:text-2xs tw:leading-none tw:ml-3")
          return label unless @error && @error_message.present?
          render(UI::Tooltip::Component.new(text: @error_message)) { label }
        end

        def has_results?
          !@error && @result_count > 0
        end

        # The atom sets its own color and weight, so these can't sit on the link.
        # The padding has to, though - the badge is a flex row, and an inline
        # element's vertical padding doesn't grow the line box
        def link_text_classes
          "tw:underline! tw:hover:font-bold! tw:text-emerald-900! tw:dark:text-emerald-200!"
        end

        def badge_classes
          color = if @error
            :error
          else
            (has_results? ? :success : :gray)
          end
          cursor = (@error && @error_message.present?) ? "tw:cursor-help" : "tw:cursor-default"
          b_classes = UI::Badge::Component.badge_classes(color:, size: :md, cursor:)
          b_classes += " tw:p-0! tw:cursor-pointer" if has_results?
          b_classes
        end
      end
    end
  end
end
