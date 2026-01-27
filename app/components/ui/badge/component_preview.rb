# frozen_string_literal: true

module UI::Badge
  class ComponentPreview < ApplicationComponentPreview
    # @group Colors
    def green
      render(UI::Badge::Component.new(text: "Donor", color: :green))
    end

    def notice_sm
      render(UI::Badge::Component.new(text: "Organization", color: :notice, size: :sm))
    end

    def purple_md
      render(UI::Badge::Component.new(text: "Superuser", color: :purple, size: :md))
    end

    def warning_lg
      render(UI::Badge::Component.new(text: "Recovery", color: :warning, size: :lg))
    end

    def gray_sm
      render(UI::Badge::Component.new(text: "Default", color: :gray, size: :sm))
    end

    def error_md
      render(UI::Badge::Component.new(text: "Banned", color: :error, size: :md))
    end

    def cyan_lg
      render(UI::Badge::Component.new(text: "Theft Alert", color: :cyan, size: :lg))
    end
    # @endgroup
  end
end
