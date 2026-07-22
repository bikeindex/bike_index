# frozen_string_literal: true

module Org
  module OriginDisplay
    class Component < ApplicationComponent
      def initialize(creation_description:)
        @creation_description = creation_description
      end

      def render?
        @creation_description.present?
      end

      def call
        safe_join([@creation_description, render(UI::Tooltip::Component.new(text: BikeServices::Displayer.origin_title(@creation_description)))], " ")
      end
    end
  end
end
