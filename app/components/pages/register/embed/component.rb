# frozen_string_literal: true

module Pages
  module Register
    module Embed
      # The whole document for step 1 framed on an organization's landing page - no analytics
      # among them, which the page around the frame counts.
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, header_tags_options:, current_user: nil, button_color: nil, button_hover_color: nil)
          @b_param = b_param
          @header_tags_options = header_tags_options
          @steps = steps
          @current_user = current_user
          @button_color = button_color
          @button_hover_color = button_hover_color
        end

        # Rendered before the document, so Pages::Register::Page's content_for(:header) is in the
        # buffer by the time <head> reads it
        def before_render
          @body = render Pages::Register::Step1::Component.new(b_param: @b_param, steps: @steps,
            current_user: @current_user, embed: true, button_color: @button_color,
            button_hover_color: @button_hover_color)
        end
      end
    end
  end
end
