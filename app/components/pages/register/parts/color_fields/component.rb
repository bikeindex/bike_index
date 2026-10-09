# frozen_string_literal: true

module Pages
  module Register
    module Parts
      module ColorFields
        # A required frame color, with up to two more revealed one at a time
        class Component < ApplicationComponent
          def initialize(form:, primary_frame_color_id: nil, secondary_frame_color_id: nil, tertiary_frame_color_id: nil)
            @form = form
            @primary_frame_color_id = primary_frame_color_id
            @additional_colors = {secondary_frame_color_id:, tertiary_frame_color_id:}
          end

          private

          def color_options
            displays = Color.pluck(:id, :display).to_h

            Color.select_options.map do |name, id|
              swatch = render(UI::ColorSwatch::Component.new(display: displays[id], name:, size: :sm))
              {value: id, display: name, content: content_tag(:span, safe_join([swatch, name]), class: "tw:inline-flex tw:items-center tw:gap-2")}
            end
          end

          def additional_color_blanks
            {secondary_frame_color_id: translation(".second_color_blank"), tertiary_frame_color_id: translation(".third_color_blank")}
          end
        end
      end
    end
  end
end
