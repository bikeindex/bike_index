# frozen_string_literal: true

module Badge::Status
  class ComponentPreview < ApplicationComponentPreview
    # @param status text "Status string to render the status badge for"
    # @param kind text "Kind of status"
    def default(kind: "marketplace_listing", status: "for_sale")
      render(Badge::Status::Component.new(kind: kind&.to_sym, status:))
    end
  end
end
