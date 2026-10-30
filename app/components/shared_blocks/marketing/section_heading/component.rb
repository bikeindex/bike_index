# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module SectionHeading
      # A marketing section's h2, with an optional label above it and intro below.
      # on_dark: the intro inside an InvertedBlock. id: the h2's, for a control it labels
      class Component < ApplicationComponent
        EYEBROW_COLORS = {blue: "tw:text-blue-600 tw:dark:text-blue-400", purple: "tw:text-purple-500 tw:dark:text-purple-300",
                          red: "tw:text-[#cc0000] tw:dark:text-red-400", yellow: "tw:text-amber-600 tw:dark:text-[#ffd660]", gray: "tw:text-gray-400"}.freeze

        def self.eyebrow_classes(color)
          "tw:text-[11.5px] tw:font-extrabold tw:tracking-widest tw:uppercase #{EYEBROW_COLORS.fetch(color)}"
        end

        def initialize(heading:, eyebrow: nil, eyebrow_color: :blue, intro: nil, on_dark: false, id: nil, html_class: nil)
          @heading = heading
          @eyebrow = eyebrow
          @eyebrow_classes = self.class.eyebrow_classes(eyebrow_color)
          @intro = intro
          @on_dark = on_dark
          @id = id
          @html_class = html_class
        end
      end
    end
  end
end
