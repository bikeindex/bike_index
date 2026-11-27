# frozen_string_literal: true

module UI
  module Forms
    module Input
      class Component < ApplicationComponent
        # Every kind takes (attribute, html_options) — a select doesn't, so it's
        # UI::Forms::Select instead. No email either: an email field is UI::Forms::Email,
        # which asks for the type itself so that every one of them checks for a typo.
        # A website is a text field because type=url refuses one typed without its https://
        TEXT_KINDS = %i[website_field postal_code_field].freeze
        KINDS = (%i[text_field text_area number_field telephone_field datetime_local_field] + TEXT_KINDS).freeze

        # Each pattern is the regex the server checks with. The browser anchors it itself, and
        # compiles it with the v flag - which needs / ( ) - escaped in a class, and a %r source to keep \/
        KIND_OPTIONS = {
          telephone_field: {pattern: Phonifyer::REGEX, autocomplete: "tel"},
          website_field: {pattern: Urlifyer::WEBSITE_REGEX, inputmode: "url", autocomplete: "url"},
          postal_code_field: {pattern: Geocodeable::POSTAL_CODE_REGEX, autocomplete: "postal-code"}
        }.transform_values { it.merge(pattern: it[:pattern].source.delete_prefix("\\A").delete_suffix("\\z")) }.freeze

        PREFIX_CLASS = "tw:flex tw:items-center tw:whitespace-nowrap tw:rounded-l-sm tw:border tw:border-r-0 " \
          "tw:border-gray-200 tw:bg-gray-100 tw:px-2.5 tw:text-gray-500 " \
          "tw:dark:border-gray-700 tw:dark:bg-gray-800 tw:dark:text-gray-400"

        # UI::Forms::Group forwards a kind here, so it validates through this too
        def self.validate_kind!(kind)
          return kind.to_sym if KINDS.include?(kind&.to_sym)

          raise ArgumentError, "unknown kind #{kind.inspect}, expected one of: #{KINDS.join(", ")}"
        end

        def initialize(form_builder:, attribute:, kind: :text_field, required: false, prefix: nil, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = self.class.validate_kind!(kind)
          @prefix = prefix.presence
          @html_options = KIND_OPTIONS.fetch(@kind, {}).merge(format_options, html_options).merge(
            {class: ["twinput", ("tw:rounded-l-none" if @prefix), html_options[:class]].compact.join(" ")},
            (required ? {required: true} : {})
          )
        end

        def call
          return field unless @prefix

          tag.div(safe_join([tag.span(@prefix, class: PREFIX_CLASS), field]), class: "tw:flex")
        end

        private

        # Without JavaScript, the browser appends the title to "Please match the requested format"
        def format_options
          message = format_message
          return {} if message.blank?

          {title: message, data: {controller: "ui--forms--format-message", "ui--forms--format-message-message-value": message,
                                  action: "invalid->ui--forms--format-message#explain input->ui--forms--format-message#reset"}}
        end

        def format_message
          case @kind
          when :telephone_field then translation(".telephone_format")
          when :website_field then translation(".website_format")
          when :postal_code_field then translation(".postal_code_format")
          end
        end

        def field
          @form_builder.send(TEXT_KINDS.include?(@kind) ? :text_field : @kind, @attribute, @html_options)
        end
      end
    end
  end
end
