# frozen_string_literal: true

# NOTE: Currently not a badge, just colored text.
module Badge::Status
  class Component < ApplicationComponent
    KINDS = %i[marketplace_listing].freeze

    def initialize(status:, kind:, status_humanized: nil)
      @status = status
      @status_humanized = status_humanized || humanize(@status)
      @kind = KINDS.include?(kind) ? kind : KINDS.first
    end

    def call
      content_tag(:span, @status_humanized, class: status_class)
    end

    def render?
      @status.present?
    end

    private

    def humanize(str)
      str&.to_s&.tr("_", " ")
    end

    def status_class
      case @status
      when "for_sale" then UI::Alert::Component::TEXT_CLASSES[:notice]
      when "sold" then UI::Alert::Component::TEXT_CLASSES[:success]
      when "removed" then UI::Alert::Component::TEXT_CLASSES[:warning]
      else
        ""
      end
    end
  end
end
