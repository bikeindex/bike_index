# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module SectionHeading
      # A marketing section's h2, with an optional label above it and intro below.
      # on_dark: the intro on a dark band. id: the h2's, for a control it labels
      class Component < ApplicationComponent
        EYEBROW_CLASSES = "tw:text-[11.5px] tw:font-extrabold tw:tracking-widest tw:uppercase"
        EYEBROW_COLORS = {blue: "tw:text-blue-600 tw:dark:text-blue-400", purple: "tw:text-purple-500 tw:dark:text-purple-300",
                          red: "tw:text-[#cc0000] tw:dark:text-red-400", yellow: "tw:text-[#ffd660]"}.freeze

        def initialize(heading:, eyebrow: nil, eyebrow_color: :blue, intro: nil, on_dark: false, id: nil, html_class: nil)
          @heading = heading
          @eyebrow = eyebrow
          @eyebrow_classes = "#{EYEBROW_CLASSES} #{EYEBROW_COLORS.fetch(eyebrow_color)}"
          @intro = intro
          @on_dark = on_dark
          @id = id
          @html_class = html_class
        end
      end
    end
  end
end
