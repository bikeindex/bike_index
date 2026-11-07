# frozen_string_literal: true

module UI
  module Accordion
    # Template Dependency: UI::Collapse::Component
    # Questions that each open their answer under them, the chevron leading - every FAQ's list.
    # items: [question, answer] pairs. The first starts open.
    # boxed: each item a white card, the whole row its trigger; the caller spaces the cards
    class Component < ApplicationComponent
      # [item, trigger, answer] classes
      STYLES = {
        rows: ["tw:border-b tw:border-gray-200 tw:py-4 tw:dark:border-gray-700",
          "tw:w-full tw:gap-2 tw:text-[17.5px] tw:font-bold tw:twtext-color",
          "tw:m-0 tw:mt-2.5 tw:pr-11 tw:text-base tw:leading-relaxed"],
        boxed: ["tw:rounded-lg tw:border tw:border-gray-200 tw:bg-white tw:dark:border-gray-700 tw:dark:bg-gray-900",
          "tw:w-full tw:gap-4 tw:px-5! tw:py-4! tw:font-header tw:text-base tw:font-bold tw:text-slate-900! tw:no-underline! tw:dark:text-gray-100!",
          "tw:m-0 tw:px-5 tw:pb-4 tw:text-[15px] tw:leading-relaxed"]
      }.freeze

      def initialize(items:, boxed: false)
        @items = items
        @item_classes, @trigger_classes, @answer_classes = STYLES.fetch(boxed ? :boxed : :rows)
      end
    end
  end
end
