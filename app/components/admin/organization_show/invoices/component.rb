# frozen_string_literal: true

module Admin
  module OrganizationShow
    module Invoices
      # What the organization has been invoiced, and its parent's invoices.
      class Component < ApplicationComponent
        def initialize(organization:)
          @organization = organization
        end
      end
    end
  end
end
