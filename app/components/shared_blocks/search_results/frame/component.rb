# frozen_string_literal: true

module SharedBlocks
  module SearchResults
    module Frame
      # Wraps an eager-loaded search results turbo-frame and its loading overlay.
      #
      # On the JS shell render (results not yet inline) the frame gets a `src` so
      # Turbo fetches the results in a separate request the moment the frame
      # connects. Without JS that `src` never fires, so a hidden spinner stands in
      # for the no-JS path instead of one that can never resolve. The caller's
      # block is the frame body, rendered once the results are present.
      #
      # A body with chrome worth keeping - a card's header and pagination - marks itself
      # .search-results-card, which stands the whole-frame overlay down; it swaps its own
      # rows for a spinner off this frame's tw:group instead.
      #
      # The form lives outside the frame and submits with turbo_action="advance",
      # so a restored snapshot can leave the frame's results stale against the
      # address-bar URL. Every search page opts out of Turbo's snapshot cache (via
      # the no-cache meta) so back/forward re-fetch the page and reload fresh.
      class Component < ApplicationComponent
        # Turbo's [busy], minus a frame holding a body that swaps its own rows. Written out
        # per utility because tailwind scans for whole class names
        FRAME_LOADING_CLASSES = "tw:[&[busy]:not(:has(>.search-results-card))]:opacity-0 " \
          "tw:[&[busy]:not(:has(>.search-results-card))]:pointer-events-none"
        OVERLAY_LOADING_CLASS = "tw:peer-[[busy]:not(:has(>.search-results-card))]:block"

        def initialize(frame_id:, render_results:, current_path:, loading_text: "Loading results...")
          @frame_id = frame_id
          @render_results = render_results
          @src = (current_path unless render_results)
          @loading_text = loading_text
        end
      end
    end
  end
end
