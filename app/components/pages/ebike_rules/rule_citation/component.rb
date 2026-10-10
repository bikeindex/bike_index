# frozen_string_literal: true

module Pages
  module EbikeRules
    module RuleCitation
      # The law a rule cites, muted after it, linked to the pages stating it - a numbered link for each of
      # several. A "source" link stands in for a rule citing no law
      class Component < ApplicationComponent
        LINK_CLASSES = "tw:underline tw:decoration-dotted tw:hover:text-gray-700 tw:dark:hover:text-gray-200"

        def initialize(restriction:)
          @citation = restriction[:citation]
          @sources = restriction[:sources].to_a
        end

        def render? = @citation.present? || @sources.any?

        def call
          tag.span(class: "tw:text-[0.85em] tw:text-gray-500 tw:dark:text-gray-400") do
            next source_link(label, @sources.first) if @sources.one?

            safe_join([label, *@sources.each_with_index.map { |url, index| source_link(index + 1, url) }], " ")
          end
        end

        private

        def label = @citation || translation(".source")

        def source_link(text, url) = link_to(text, url, target: "_blank", rel: "noopener", title: url, class: LINK_CLASSES)
      end
    end
  end
end
