# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module InvertedBlock
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(SharedBlocks::Marketing::InvertedBlock::Component.new) do
            safe_join([
              render(SharedBlocks::Marketing::SectionHeading::Component.new(eyebrow: "Partnership", eyebrow_color: :yellow,
                heading: "Your nonprofit partner", intro: "We work alongside your team", on_dark: true)),
              render(UI::ButtonLink::Component.new(href: "#", text: "Get in touch", size: :callout))
            ])
          end
        end
      end
    end
  end
end
