# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module PaymentsTable
        # The payments made against an organization's invoices, on its invoices tab.
        class Component < ApplicationComponent
          def initialize(organization:)
            @organization = organization
          end

          private

          def payments = @organization.payments.includes(:user, :invoice)
        end
      end
    end
  end
end
