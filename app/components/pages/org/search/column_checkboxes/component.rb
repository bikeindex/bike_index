# frozen_string_literal: true

module Pages
  module Org
    module Search
      module ColumnCheckboxes
        # The column checkboxes with all/none/default - the registrations search's column panel and
        # the export form both render theirs with it. Each column is {name:, value:, label:, checked:,
        # default:}, plus disabled: for one that's always shown
        class Component < ApplicationComponent
          # Unchecked columns read quieter than the ones showing
          LABEL_CLASSES = "tw:mb-0! tw:leading-[1.25]! tw:text-gray-400 tw:has-checked:text-gray-900 tw:dark:has-checked:text-gray-100"

          # data: joins the element's own, for a caller's controller to watch its changes
          def initialize(heading:, columns:, data: {})
            @heading = heading
            @columns = columns
            @data = data
          end

          private

          def column_rows = (@columns.size / 3.0).ceil
        end
      end
    end
  end
end
