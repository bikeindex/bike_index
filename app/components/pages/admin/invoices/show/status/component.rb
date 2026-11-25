# frozen_string_literal: true

module Pages
  module Admin
    module Invoices
      module Show
        module Status
          # Whether an invoice is active, and when it expires.
          class Component < ApplicationComponent
            def initialize(invoice:)
              @invoice = invoice
            end
          end
        end
      end
    end
  end
end
