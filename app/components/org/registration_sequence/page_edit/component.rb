# frozen_string_literal: true

module Org
  module RegistrationSequence
    module PageEdit
      class Component < ApplicationComponent
        def initialize(form_builder:)
          @form_builder = form_builder
        end

        private

        # The page stores its bullets as a single body <ul> of <li>s; split it back into
        # one editable bullet each, falling back to one empty bullet so a row always shows.
        def bullets
          html = @form_builder.object.body
          return [""] if html.blank?

          items = Nokogiri::HTML.fragment(html).css("li")
          items.any? ? items.map { it.inner_html.strip } : [html.strip]
        end
      end
    end
  end
end
