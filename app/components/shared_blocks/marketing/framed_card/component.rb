# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module FramedCard
      # A card for one of our tools, showing the live page in a scaled, inert frame, and linking to it.
      # frame_class sets --frame-scale, and the --frame-crop-top and --frame-crop-x the frame cuts off its page
      # (an #anchor would scroll this page too)
      class Component < ApplicationComponent
        def initialize(href:, frame:, frame_class:, icon:, circle:, title:, body:, action:, eyebrow: nil)
          @href = href
          @frame = frame
          @frame_class = frame_class
          @icon = icon
          @circle = circle
          @title = title
          @body = body
          @action = action
          @eyebrow = eyebrow
        end
      end
    end
  end
end
