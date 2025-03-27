# frozen_string_literal: true

module Alert
  class ComponentPreview < ApplicationComponentPreview
    # @group Kind Variants
    # @param kind "The kind of alert"
    def info(kind: :info)
      render(Alert::Component.new(text: default_text, kind:))
    end

    def danger(kind: :danger)
      render(Alert::Component.new(text: default_text, kind:))
    end

    def warning(kind: :warning)
      render(Alert::Component.new(text: default_text, kind:))
    end

    def success(kind: :success)
      render(Alert::Component.new(text: default_text, kind:))
    end

    # @group Dismissable Variants
    # @param kind "The kind of alert"
    def dismissable_info(kind: :info)
      render(Alert::Component.new(text: default_text, kind:, dismissable: true))
    end

    def dismissable_danger(kind: :danger)
      render(Alert::Component.new(text: default_text, kind:, dismissable: true))
    end

    def dismissable_warning(kind: :warning)
      render(Alert::Component.new(text: default_text, kind:, dismissable: true))
    end

    def dismissable_success(kind: :success)
      render(Alert::Component.new(text: default_text, kind:, dismissable: true))
    end

    private

    def default_text
      "A simple alert with some info in it"
    end
  end
end
