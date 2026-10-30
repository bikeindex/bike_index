# frozen_string_literal: true

module UI
  module CardTable
    # A UI::Table that fills a card edge to edge, its first column frozen against the
    # horizontal scroll. Columns are declared as on UI::Table, and their blocks run there.
    # Given column_settings, it renders its own full-bleed card, under them
    class Component < ApplicationComponent
      # Template Dependency: UI::Card::Component
      renders_one :description
      renders_one :actions

      # Descendant selectors, so they outrank the cell classes UI::Table gives every column
      TABLE_CLASSES = [
        "tw:[&_th]:whitespace-nowrap tw:[&_th]:border-b tw:[&_th]:border-gray-100 tw:[&_th]:bg-gray-50",
        "tw:[&_th]:px-4 tw:[&_th]:py-2.5 tw:[&_th]:text-2xs tw:[&_th]:font-normal tw:[&_th]:text-gray-400 tw:[&_th]:uppercase",
        # twlink's blue gives way to the header's gray, underlined like twlink-underlined
        "tw:[&_th_a]:text-inherit tw:[&_th_a]:underline tw:[&_th_a:hover]:decoration-2 tw:[&_th_a[data-active]]:decoration-2",
        "tw:[&_td]:bg-white tw:[&_td]:px-4 tw:[&_td]:py-2.5 tw:[&_td]:text-sm tw:[&_tr:hover_td]:bg-amber-50",
        # Whatever follows the table draws the line under it
        "tw:[&_tbody_tr:last-child_td]:border-b-0",
        "tw:dark:[&_th]:border-gray-700 tw:dark:[&_th]:bg-gray-800 tw:dark:[&_td]:bg-gray-900",
        "tw:dark:[&_tr:hover_td]:bg-gray-800"
      ].join(" ").freeze

      # Shadowed once the ui--table-overflow controller flags there's any to scroll
      FROZEN_COLUMN_CLASSES = "tw:w-px tw:sticky tw:left-0 tw:z-1 tw:border-r tw:border-r-gray-100 " \
        "tw:group-data-overflowing/card-table:shadow-[2px_0_6px_rgba(26,26,31,0.04)] tw:dark:border-r-gray-700"

      # [&>div] is UI::Table's scroller, whose bottom spacing would part the table from what
      # follows it. The after: box mirrors the frozen column's divider and shadow on the right
      # edge while there's more to scroll, except in a full-bleed row that runs off the page
      WRAPPER_CLASSES = "tw:group/card-table tw:relative tw:[&>div]:mb-0 tw:[&>div]:pb-0 tw:data-overflowing:after:absolute " \
        "tw:data-overflowing:after:inset-y-0 tw:data-overflowing:after:left-[calc(100%-1px)] tw:data-overflowing:after:z-2 " \
        "tw:data-overflowing:after:w-4 tw:data-overflowing:after:border-l tw:data-overflowing:after:border-gray-100 " \
        "tw:data-overflowing:after:shadow-[-2px_0_6px_rgba(26,26,31,0.04)] tw:dark:data-overflowing:after:border-gray-700 " \
        "tw:data-scrolled-end:after:hidden tw:@max-[672px]/twwiderow:after:hidden"

      # column_settings: UI::TableColumnSettings' columns, defaults and narrow_hidden, plus its storage_key.
      # form: form_with's options, making the card a form whose actions apply to the rows checked in
      # selection_column. data: the outermost element's, its controllers and actions joining these.
      # The rest go to UI::Table
      def initialize(column_settings: nil, form: nil, data: {}, **table_options)
        @column_settings = column_settings
        @form = form
        @data = data
        @table_options = table_options
        @columns = []
      end

      # hideable: the column's cell_name, labeled by column_settings
      def column(hideable: nil, **options, &block)
        if hideable
          options = options.merge(label: @column_settings&.dig(:columns, hideable), classes: token_list("hideableColumn", hideable, options[:classes]))
        end
        @columns << [options, block]
        nil
      end

      # The form's checkboxes, named param[id] for the row's record - or the first of its array, which
      # disabled is called with. The block renders beside each
      def selection_column(param:, disabled: nil, &block)
        column(label: toggle_all_button) do |row|
          record = row.is_a?(Array) ? row.first : row
          checkbox = check_box_tag("#{param}[#{record.id}]", record.id, false, disabled: disabled&.call(record),
            aria: {label: "Select #{record.model_name.human.downcase} #{record.id}"}, data: {"table-multi-checkbox-target" => "checkbox"})
          next checkbox unless block

          tag.div(safe_join([checkbox, capture { instance_exec(row, &block) }]), class: "tw:flex tw:items-center tw:gap-3")
        end
      end

      def before_render
        content
      end

      private

      def toggle_all_button
        render(UI::Button::Component.new(text: check_mark, color: :link, title: "Toggle all checked",
          aria: {label: "Toggle all checked"}, data: {action: "click->table-multi-checkbox#toggleAll"}))
      end

      def wrapper_data
        data = @column_settings ? {} : @data
        data.merge(controller: token_list("ui--table-overflow", data[:controller]))
      end

      def card(&)
        classes = "tw:col-span-full tw:min-w-0 tw:rounded-xl tw:twfullbleed #{UI::Card::Component::BASE_CLASSES}"
        return form_with(**@form, class: classes, data: card_data, &) if @form

        tag.div(class: classes, data: card_data, &)
      end

      def card_data
        data = UI::TableColumnSettings::Component.data_attributes(storage_key: @column_settings[:storage_key], orderable: true,
          controllers: token_list(("table-multi-checkbox" if @form), @data[:controller]).presence)
        selection = "input->table-multi-checkbox#selectRow submit->table-multi-checkbox#confirmDiscard" if @form
        @data.merge(data, action: token_list(data[:action], selection, @data[:action]))
      end

      def column_options(options, index)
        options.merge(classes: [(FROZEN_COLUMN_CLASSES if index.zero?), options[:classes]].compact.join(" "))
      end
    end
  end
end
