# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module SectionHeading
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants
        def default
          render(SharedBlocks::Marketing::SectionHeading::Component.new(eyebrow: "Registration",
            heading: "Every bike in your city, in one searchable registry",
            intro: "Registrations from bike shops, schools and residents land in one place your staff can search."))
        end

        def heading_only
          render(SharedBlocks::Marketing::SectionHeading::Component.new(heading: "Questions"))
        end

        def purple_label
          render(SharedBlocks::Marketing::SectionHeading::Component.new(eyebrow: "Major giving", eyebrow_color: :purple,
            heading: "Larger gifts move whole cities onto the registry"))
        end
        # @!endgroup
      end
    end
  end
end
