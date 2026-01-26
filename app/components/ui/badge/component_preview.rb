# frozen_string_literal: true

module UI::Badge
  class ComponentPreview < ApplicationComponentPreview
    # @group Colors
    def emerald
      render(UI::Badge::Component.new(text: "Donor", color: :emerald))
    end

    def blue
      render(UI::Badge::Component.new(text: "Organization", color: :blue))
    end

    def purple
      render(UI::Badge::Component.new(text: "Superuser", color: :purple))
    end

    def amber
      render(UI::Badge::Component.new(text: "Recovery", color: :amber))
    end

    def cyan
      render(UI::Badge::Component.new(text: "Theft Alert", color: :cyan))
    end

    def red
      render(UI::Badge::Component.new(text: "Banned", color: :red))
    end

    def red_light
      render(UI::Badge::Component.new(text: "Email Banned", color: :red_light))
    end

    def gray
      render(UI::Badge::Component.new(text: "Default", color: :gray))
    end
    # @endgroup
  end
end
