# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module InvertedBlock
      # A band in the opposite of the page's mode, with its content in two columns. Content
      # styles itself as for the page - `inverted` flips tw:dark: inside it
      class Component < ApplicationComponent
        def initialize(html_class: nil)
          @html_class = html_class.to_s.include?("tw:py-") ? html_class : ["tw:py-20", html_class].compact.join(" ")
        end
      end
    end
  end
end
