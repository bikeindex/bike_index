# frozen_string_literal: true

module Pages
  module Bikebook
    module SchemaViewer
      # The fields of each document the catalog publishes, with how many models hold each value.
      # viewer: Integrations::Bikebook::Catalog.schema_viewer
      # open: the paths of the folded objects and enums rendered open
      # by_count: the paths of the open enums ordering their values by count
      class Component < ApplicationComponent
        def initialize(viewer:, document:, open: [], by_count: [])
          @viewer = viewer
          @document = document
          @open = open
          @by_count = by_count
        end

        private

        def tabs = @viewer["documents"].keys.map { ComponentStructs::Shapes.tab(it.humanize, bikebook_schema_viewer_path(document: it), active: it == @document) }

        def url = @viewer.dig("documents", @document, "url")
      end
    end
  end
end
