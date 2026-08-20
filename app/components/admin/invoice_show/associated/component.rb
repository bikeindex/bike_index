# frozen_string_literal: true

module Admin
  module InvoiceShow
    module Associated
      # An invoice's neighbours in its organization's sequence, and what has been paid against it.
      class Component < ApplicationComponent
        def initialize(invoice:)
          @invoice = invoice
        end
      end
    end
  end
end
