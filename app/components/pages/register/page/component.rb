# frozen_string_literal: true

module Pages
  module Register
    module Page
      # Full-bleed gray shell for the registration flow pages. The negative
      # margins pull over the layout's nav/footer spacing so the gray runs
      # edge to edge; content is centered at form width.
      class Component < ApplicationComponent
        # data: for a step-wide controller, since this wraps everything on the page
        # (register--heading needs both the heading and the form in scope).
        # wide: for a page that isn't a form - the finished theft report's checklist
        # embed: framed on someone else's page, which supplies the shell instead
        def initialize(data: {}, wide: false, embed: false)
          @data = data
          @wide = wide
          @embed = embed
        end

        def call
          # Which step a page shows is server state, and Turbo restores its own snapshot on
          # back/forward - the cache Cache-Control: no-store can't reach
          helpers.content_for(:header) { tag.meta(name: "turbo-cache-control", content: "no-cache") }

          content_tag(:div,
            content_tag(:div, safe_join([retry_notice, content]),
              class: "tw:mx-auto #{@wide ? "tw:max-w-3xl" : "tw:max-w-md"}"),
            class: shell_class,
            data: @data.merge(controller: ["register--revalidate", @data[:controller]].compact.join(" ")))
        end

        private

        # p-1 so a focus ring at the form's edge isn't clipped by the frame
        def shell_class
          return "tw:p-1" if @embed

          "tw:-mt-(--nav-gap) tw:-mb-18 tw:bg-gray-100 tw:px-4 tw:py-10 tw:dark:bg-gray-900"
        end

        # Revealed by register--retry when a submission can't be retried into working. Ships
        # with the page rather than built in JS, so it's translated and styled like any alert
        def retry_notice
          content_tag(:div, render(UI::Alerts::Base::Component.new(kind: :error, text: translation(".retry_failed"))),
            hidden: true, data: {register_retry_notice: true})
        end
      end
    end
  end
end
