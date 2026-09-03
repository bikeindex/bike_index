# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class Component < ApplicationComponent
        # The label is lowercase and the tooltip a lowercase sentence, so the only title case
        # anywhere is a name inside one - the flow, the POS product
        EXTENDED_DESCRIPTIONS = {
          "web" => "registered with self registration process",
          "org reg" => "registered by internal, organization member form",
          "landing page" => "registration began with incomplete registration, via organization landing page",
          "bulk import" => "registered by spreadsheet import",
          "parking notification" => "registered via the Unregistered Parking Notification flow",
          "register flow" => "registered with the multi-step registration flow",
          "register flow organized" => "registered by an organization member, in the multi-step registration flow",
          "register flow landing page" => "registration began via an organization landing page, in the multi-step registration flow",
          "Lightspeed" => "automatically registered by bike shop point of sale (Lightspeed POS)",
          "Ascend" => "automatically registered by bike shop point of sale (Ascend POS)"
        }.freeze
        LABELS = {
          "parking notification" => "unregistered parking notification",
          "landing page" => "old landing page",
          "register flow" => "new flow",
          "register flow organized" => "new flow organized",
          "register flow landing page" => "landing page"
        }.freeze

        def initialize(creation_description:)
          @creation_description = creation_description
        end

        def render?
          @creation_description.present?
        end

        def call
          safe_join([label, render(UI::Tooltip::Component.new(text: origin_title))], " ")
        end

        private

        def label
          (LABELS[@creation_description] || @creation_description).downcase
        end

        def origin_title
          EXTENDED_DESCRIPTIONS[@creation_description] || "registered via #{@creation_description}"
        end
      end
    end
  end
end
