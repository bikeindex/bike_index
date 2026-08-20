# frozen_string_literal: true

module Admin
  module InvoiceShow
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
