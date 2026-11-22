# frozen_string_literal: true

module Pages
  module Bikebook
    module Schema
      # A record's file in the bikebook repository, pretty-printed in its own key order, each line commented with the
      # schema viewer's description of its field and of its value.
      # json: nil while the repository doesn't answer
      class Component < ApplicationComponent
        Line = Data.define(:depth, :key, :value, :tail, :comment)
        MUTED_CLASSES = "tw:text-gray-400 tw:dark:text-gray-500"

        def initialize(id:, json:)
          @id = id
          @json = json
        end

        private

        def github_url = "#{Integrations::Bikebook::Catalog::GITHUB_REPO_URL}/blob/main/#{Integrations::Bikebook::RepositoryRecord.path(@id)}"

        def fields = Integrations::Bikebook::Catalog.schema_viewer.dig("documents", Integrations::Bikebook::RepositoryRecord.document(@id), "fields")

        def code = tag.pre(safe_join(lines(JSON.parse(@json), {"fields" => fields}).map { line_tag(it) }),
          class: "tw:overflow-x-auto tw:font-mono tw:text-sm tw:leading-6")

        # JSON.pretty_generate's lines
        def lines(value, field, depth = 0, key = nil, comma = "")
          comment = [field["description"], field["values"]&.find { it["value"] == value }&.dig("description")].compact.join("; ").presence
          entries = case value
          when Hash then value.map { |name, each| [name, each, child(field, name)] }
          when Array then value.map { [nil, it, item(field)] }
          end
          return [Line.new(depth, key, JSON.generate(value), comma, comment)] if entries.blank?

          open, close = value.is_a?(Hash) ? %w[{ }] : %w([ ])
          [Line.new(depth, key, nil, open, comment),
            *entries.each_with_index.flat_map { |(name, each, schema), index| lines(each, schema, depth + 1, name, (index < entries.length - 1) ? "," : "") },
            Line.new(depth, nil, nil, "#{close}#{comma}", nil)]
        end

        # every entry of an object keyed by year has the fields of `each`
        def child(field, name) = field["keyed_by"] ? {"fields" => field["each"]} : field.dig("fields", name) || {}

        def item(field) = field["each"] ? {"fields" => field["each"]} : field.slice("values")

        def line_tag(line)
          code = safe_join(["  " * line.depth, line.key && tag.span("#{JSON.generate(line.key)}:", class: "tw:text-blue-700 tw:dark:text-blue-300"),
            line.key && " ", line.value && tag.span(line.value, class: Pages::Bikebook::SchemaFields::Component::VALUE_CLASSES), line.tail].compact)
          comment = line.comment && tag.span("// #{line.comment}", class: "tw:min-w-0 tw:whitespace-pre-wrap #{MUTED_CLASSES}")
          tag.span(safe_join([tag.span(code, class: "tw:shrink-0"), comment].compact, " "), class: "tw:flex tw:gap-2")
        end
      end
    end
  end
end
