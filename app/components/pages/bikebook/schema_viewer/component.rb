# frozen_string_literal: true

module Pages
  module Bikebook
    module SchemaViewer
      # The fields of each document the catalog publishes, with how many models hold each value, or one record's file.
      # viewer: Integrations::Bikebook::Catalog.schema_viewer, nil while the catalog doesn't answer
      # open: the paths of the folded objects and enums rendered open
      # by_count: the paths of the open enums ordering their values by count
      # record_id: the record whose file shows in place of the fields, record its file parsed, nil while the bikebook
      # repository doesn't answer
      class Component < ApplicationComponent
        def initialize(viewer:, document:, open: [], by_count: [], record_id: nil, record: nil)
          @viewer = viewer
          @document = document
          @open = open
          @by_count = by_count
          @record_id = record_id
          @record = record
        end

        private

        def tabs = @viewer["documents"].keys.map { ComponentStructs::Shapes.tab(it.humanize, bikebook_schemas_path(document: it), active: it == @document) }

        def url = @viewer.dig("documents", @document, "url")

        def fields = @viewer&.dig("documents", @document, "fields")

        # what the combobox shows for the record, as /bikebook names it
        def record_display = @record && [@record["manufacturer"], @record["model"] || @record["name"]].compact.join(" ")
      end
    end
  end
end
