# frozen_string_literal: true

module Atoms
  module Admin
    module Badges
      module BugReportTag
        class Component < ApplicationComponent
          PREFIX_COLORS = {"ask_" => :notice, "area_" => :purple}.freeze

          TAG_COLORS = {
            "bug" => :error,
            BugReport::SPAM_TAG => :orange,
            BugReport::FEEDBACK_TAG => :success,
            BugReport::AUTO_REPLY_TAG => :gray,
            BugReport::INTERNAL_NOTIFICATION_TAG => :cyan
          }.freeze

          # Tags added by hand get a color of their own, the same one every time
          OTHER_COLORS = %i[warning pink rose yellow empty].freeze

          def initialize(tag:)
            @tag = tag
          end

          def call
            content_tag(:span, safe_join([@tag, content].compact), class: [UI::Badge::Component.badge_classes(color:, size: :sm), "tw:font-mono"])
          end

          private

          def color
            PREFIX_COLORS.find { |prefix, _| @tag.start_with?(prefix) }&.last ||
              TAG_COLORS[@tag] ||
              OTHER_COLORS[Zlib.crc32(@tag) % OTHER_COLORS.length]
          end
        end
      end
    end
  end
end
