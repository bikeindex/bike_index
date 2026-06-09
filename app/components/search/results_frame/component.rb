# frozen_string_literal: true

module Search
  module ResultsFrame
    # Wraps an eager-loaded search results turbo-frame and its loading overlay.
    #
    # On the JS shell render (results not yet inline) the frame gets a `src` so
    # Turbo fetches the results in a separate request the moment the frame
    # connects. Without JS that `src` never fires, so a hidden spinner stands in
    # for the no-JS path instead of one that can never resolve. The caller's
    # block is the frame body, rendered once the results are present.
    #
    # The form lives outside the frame and submits with turbo_action="advance",
    # so a restored snapshot can leave the frame's results stale against the
    # address-bar URL. Every search page opts out of Turbo's snapshot cache (via
    # the no-cache meta) so back/forward re-fetch the page and reload fresh.
    class Component < ApplicationComponent
      def initialize(frame_id:, render_results:, current_path:, loading_text: "Loading results...")
        @frame_id = frame_id
        @render_results = render_results
        @src = (current_path unless render_results)
        @loading_text = loading_text
      end
    end
  end
end
