# frozen_string_literal: true

module Pages
  module Donate
    module FormCard
      # The box a donate page puts Pages::Donate::Form in, its content. #donate-form is what the page's
      # links and buttons scroll to. html_class places it in the page's layout
      class Component < ApplicationComponent
        def initialize(title:, subtitle: nil, html_class: nil)
          @title = title
          @subtitle = subtitle
          @html_class = html_class
        end
      end
    end
  end
end
