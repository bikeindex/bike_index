# frozen_string_literal: true

module Register
  module Page
    # Full-bleed gray shell for the registration flow pages. The negative
    # margins pull over the layout's nav/footer spacing so the gray runs
    # edge to edge; content is centered at form width.
    class Component < ApplicationComponent
      # data: for a step-wide controller, since this wraps everything on the page
      # (register--heading needs both the heading and the form in scope)
      def initialize(data: {})
        @data = data
      end

      def call
        # Which step a page shows depends on server state, and Turbo restores its own
        # snapshot on back/forward - the cache Cache-Control: no-store can't reach
        helpers.content_for(:header) { tag.meta(name: "turbo-cache-control", content: "no-cache") }

        content_tag(:div,
          content_tag(:div, safe_join([retry_notice, content]), class: "tw:mx-auto tw:max-w-md"),
          class: "tw:-mt-9 tw:-mb-18 tw:bg-gray-100 tw:px-4 tw:py-10 tw:min-[992px]:-mt-15 tw:dark:bg-gray-900",
          data: @data.merge(controller: ["register--revalidate", @data[:controller]].compact.join(" ")))
      end

      private

      # Revealed by register--retry when a step's submission can't be retried into working.
      # Ships with the page rather than being built in JS, so it's translated and styled
      # like every other alert - and so a step that fails says something either way
      def retry_notice
        content_tag(:div, render(UI::Alerts::Base::Component.new(kind: :error, text: translation(".retry_failed"))),
          hidden: true, data: {register_retry_notice: true})
      end
    end
  end
end
