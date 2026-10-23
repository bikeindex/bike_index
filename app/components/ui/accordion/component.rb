# frozen_string_literal: true

module UI
  module Accordion
    # Template Dependency: UI::Collapse::Component
    # Questions that each open their answer under them, the chevron leading - every FAQ's list.
    # items: [question, answer] pairs. The first starts open
    class Component < ApplicationComponent
      def initialize(items:)
        @items = items
      end
    end
  end
end
