# frozen_string_literal: true

module Pages
  module Bikes
    module StolenChecklist
      module NetherlandsPoliceReport
        # The ways to file a police report in the Netherlands, as items for the caller's list
        class Component < ApplicationComponent
          # The marker is a dash rather than the parent checklist's circle
          DASH_CLASSES = "tw:absolute tw:top-3 tw:left-1 tw:block tw:min-h-[0.2em] tw:min-w-6 " \
            "tw:border-2 tw:border-[#919197] tw:bg-[#919197]"

          # checklist: styled as Pages::Bikes::StolenChecklist's sub-items, which the stolen bike alert email renders too
          def initialize(checklist: false)
            @checklist = checklist
          end

          private

          def item_class = (Pages::Bikes::StolenChecklist::Component::ITEM_CLASSES if @checklist)

          def marker = (tag.span("", class: "checklist-uncheckbox #{DASH_CLASSES}") if @checklist)

          def link_class = @checklist ? "twlink-underlined" : "twlink"
        end
      end
    end
  end
end
