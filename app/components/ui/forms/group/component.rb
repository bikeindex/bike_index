# frozen_string_literal: true

module UI
  module Forms
    module Group
      class Component < ApplicationComponent
        # Text under the field. The input points at it with aria-describedby -- a
        # content block renders its own field, so it passes helper_text_id itself.
        renders_one :helper_text

        # Pass a block (a UI::Forms::Combobox, Select, TextEditor...) and it renders in
        # place of the input -- `kind` is then unused. Without a form_builder that block
        # is the only valid shape: the label falls back to label_tag, so it points at
        # whatever the block renders with the attribute's id.
        # required_toggleable: the answer is decided in the browser, so the label renders
        # both markers with the inactive one hidden - it can't be rebuilt from JS. They're
        # [data-required-marker] and [data-optional-marker] for whichever controller flips them
        def initialize(attribute:, form_builder: nil, kind: :text_field, label_text: nil, required: false,
          required_toggleable: false, prefix: nil, wrapper_class: "tw:mb-4", html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = Input::Component.validate_kind!(kind)
          @label_text = label_text || attribute.to_s.humanize
          @required = required
          @prefix = prefix
          @required_toggleable = required_toggleable
          @wrapper_class = wrapper_class
          @html_options = html_options
        end

        def before_render
          raise ArgumentError, "pass form_builder, or a content block" if @form_builder.nil? && !content_field?
        end

        # aria-describedby for a field a content block renders, which Group can't reach
        def helper_text_id
          @helper_text_id ||= "#{@form_builder&.field_id(@attribute) || @attribute}_helper"
        end

        private

        # content? is true for a block that only sets the helper_text slot, so the
        # field it renders is what decides whether to fall back to UI::Forms::Input
        def content_field?
          content.present?
        end

        def input_html_options
          return @html_options unless helper_text?

          @html_options.merge("aria-describedby" => helper_text_id)
        end

        def label_markup
          if @form_builder
            @form_builder.label(@attribute, label_content, class: "twlabel")
          else
            label_tag(@attribute, label_content, class: "twlabel")
          end
        end

        # The label carries a required "*" or an "optional" badge, keyed off required?.
        def label_content
          safe_join([@label_text, label_suffix_markup], " ")
        end

        def label_suffix_markup
          return required? ? required_marker : optional_marker unless @required_toggleable

          safe_join([tag.span(required_marker, data: {required_marker: true}, hidden: !required?),
            tag.span(optional_marker, data: {optional_marker: true}, hidden: required?)])
        end

        def required_marker = tag.span("*", class: "tw:text-red-600")

        def optional_marker = render(UI::Badge::Component.new(text: translation(".optional"), size: :xs))

        def required?
          @required || ActiveModel::Type::Boolean.new.cast(@html_options[:required])
        end
      end
    end
  end
end
