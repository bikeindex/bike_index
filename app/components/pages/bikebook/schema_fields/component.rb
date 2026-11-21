# frozen_string_literal: true

module Pages
  module Bikebook
    module SchemaFields
      # One level of a schema document's fields, rendering its objects' fields beneath them
      class Component < ApplicationComponent
        # an enum longer than this shows its first few values until opened
        INLINE_ENUM_LIMIT = 6
        PREVIEW_ENUM_LENGTH = 3
        # an opened enum longer than this wraps rather than taking a line per value
        LINED_ENUM_LIMIT = 14
        PLACEHOLDERS = {"integer" => "number", "float" => "number"}.freeze
        VALUE_CLASSES = "tw:text-purple-700 tw:dark:text-purple-300"

        def initialize(fields:, open:, by_count:, representative_ids:, path: nil)
          @fields = fields
          @open = open
          @by_count = by_count
          @representative_ids = representative_ids
          @path = path
        end

        private

        def field_path(name) = [@path, name].compact.join(".")

        def brackets(field)
          if field["keyed_by"] then ["{ <#{field["keyed_by"]}>: {", "} }"]
          elsif field["each"] then ["[{", "}]"]
          elsif field["fields"] then ["{", "}"]
          end
        end

        def children(field) = field["fields"] || field["each"]

        # a field without a description of its own leaves it to its values', which only show opened
        def folded?(field) = field["values"].length > INLINE_ENUM_LIMIT || (!field["description"] && field["values"].any? { it["description"] })

        def enum_text(values) = safe_join(values.map { safe_join([tag.span(it["value"], class: VALUE_CLASSES, title: it["description"]), count_badge(it)].compact, " ") }, " | ")

        # counted: a value, or a string or number field, counting the models filling it
        def count_badge(counted)
          return unless counted["models_count"]
          render(UI::Tooltip::Component.new(text: translation(".models", number: number_with_delimiter(counted["models_count"])))) do |tooltip|
            tooltip.with_body { tag.ul(safe_join(counted["example_ids"].map { example_item(it) }), class: "tw:space-y-1 tw:p-1") }
            tag.span(render(UI::Badge::Component.new(text: number_display(counted["models_count"]), size: :xs)), class: "tw:*:cursor-pointer")
          end
        end

        def example_item(id)
          representative = tag.span(translation(".representative"), class: "tw:shrink-0 tw:text-gray-500") if @representative_ids.include?(id)
          link = link_to(id, ReadableQuery.path(bikebook_path, "vehicle_models" => id), class: "twlink tw:font-mono")
          tag.li(safe_join([link, representative].compact, " "), class: "tw:flex tw:items-center tw:gap-1")
        end

        # each value's place counting down from the most models, for CSS order to sort the lines by
        def count_ranks(values) = values.sort_by.with_index { |value, index| [-value["models_count"].to_i, index] }.each_with_index.to_h { |value, rank| [value["value"], rank] }

        def placeholder(field) = [PLACEHOLDERS.fetch(field["of"] || field["type"], field["of"] || field["type"]), field["unit"]].compact.join(" ")
      end
    end
  end
end
