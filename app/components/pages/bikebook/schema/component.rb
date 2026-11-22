# frozen_string_literal: true

module Pages
  module Bikebook
    module Schema
      # A record's file in the bikebook repository, pretty-printed in its own key order, each line commented with the
      # schema viewer's description of its field and of its value, uncommented while the catalog doesn't answer.
      # json: nil while the repository doesn't answer
      class Component < ApplicationComponent
        LINE = /\A( *)("(?:[^"\\]|\\.)*": )?(.*?)(,?)\z/

        def initialize(id:, json:)
          @id = id
          @json = json
        end

        private

        def github_url = "#{Integrations::Bikebook::Catalog::GITHUB_REPO_URL}/blob/main/#{Integrations::Bikebook::RepositoryRecord.path(@id)}"

        def fields = Integrations::Bikebook::Catalog.schema_viewer&.dig("documents", Integrations::Bikebook::RepositoryRecord.document(@id), "fields")

        def code
          record = JSON.parse(@json)
          lines = JSON.pretty_generate(record).lines(chomp: true).zip(comments(record, {"fields" => fields}))
          tag.pre(safe_join(lines.map { line_tag(*it) }), class: "tw:overflow-x-auto tw:font-mono tw:text-sm tw:leading-6")
        end

        # One for each of JSON.pretty_generate's lines, an object or array closing on a line of its own
        def comments(value, field)
          comment = [field["description"], field["values"]&.find { it["value"] == value }&.dig("description")].compact.join("; ").presence
          children = case value
          when Hash then value.flat_map { |name, each| comments(each, child(field, name)) }
          when Array then value.flat_map { comments(it, item(field)) }
          end
          children.present? ? [comment, *children, nil] : [comment]
        end

        # every entry of an object keyed by year has the fields of `each`
        def child(field, name) = field["keyed_by"] ? item(field) : field.dig("fields", name) || {}

        def item(field) = field["each"] ? {"fields" => field["each"]} : field.slice("values")

        def line_tag(line, comment)
          indent, key, value, comma = line.match(LINE).captures
          value = tag.span(value, class: Pages::Bikebook::SchemaFields::Component::VALUE_CLASSES) unless %w[{ [ } ]].include?(value)
          code = tag.span(safe_join([indent, key && tag.span(key, class: "tw:text-blue-700 tw:dark:text-blue-300"), value, comma].compact), class: "tw:shrink-0")
          comment &&= tag.span("// #{comment}", class: "tw:min-w-0 tw:whitespace-pre-wrap tw:text-gray-400 tw:dark:text-gray-500")
          tag.span(safe_join([code, comment].compact, " "), class: "tw:flex tw:gap-2")
        end
      end
    end
  end
end
