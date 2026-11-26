# frozen_string_literal: true

module Atoms
  module Org
    module RegistrationLink
      # The organization's public registration link, to copy, with its QR code behind a toggle
      class Component < ApplicationComponent
        def initialize(organization:, html_class: nil)
          @organization = organization
          @html_class = html_class
        end

        private

        def registration_url = register_organization_url(@organization)

        def qr_code_path = register_organization_path(@organization, format: :png)

        def card_classes = ["tw:rounded-lg! tw:p-7!", @html_class].compact.join(" ")
      end
    end
  end
end
