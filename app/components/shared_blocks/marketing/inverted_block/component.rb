# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module InvertedBlock
      # A band in the opposite of the page's mode. Content styles itself as for the page - `inverted`
      # flips tw:dark: inside it. layout: :columns puts the content in two columns, :stacked one above another
      class Component < ApplicationComponent
        BAND_CLASSES = "inverted tw:bg-linear-160 tw:from-white tw:to-gray-100 tw:text-slate-900 " \
          "tw:dark:from-slate-900 tw:dark:to-[#233140] tw:dark:text-white"

        LAYOUTS = {columns: "tw:grid tw:grid-cols-[repeat(auto-fit,minmax(min(100%,380px),1fr))] tw:items-center tw:gap-12",
                   stacked: "tw:flex tw:flex-col tw:gap-9"}.freeze

        def initialize(layout: :columns, html_class: nil)
          @layout_classes = LAYOUTS.fetch(layout)
          @html_class = html_class.to_s.include?("tw:py-") ? html_class : ["tw:py-20", html_class].compact.join(" ")
        end
      end
    end
  end
end
