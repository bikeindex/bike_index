# frozen_string_literal: true

module UI
  module Forms
    module Group
      class Component < ApplicationComponent
        # label_suffix: markup after the label text. Defaults to a required "*" when the
        # field is required, otherwise an "optional" badge. Pass nil to omit, or custom
        # markup to override.
        def initialize(form_builder:, attribute:, kind: :text_field, label_text: nil, label_suffix: :default,
          required: false, wrapper_class: "tw:mb-4", html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = kind.to_sym
          @label_text = label_text || attribute.to_s.humanize
          @label_suffix = label_suffix
          @required = required
          @wrapper_class = wrapper_class
          @html_options = html_options
        end

        private

        def label_content
          safe_join([@label_text, label_suffix_markup].compact, " ")
        end

        def label_suffix_markup
          return if @label_suffix.blank?
          return @label_suffix unless @label_suffix == :default

          if required?
            tag.span("*", class: "tw:text-red-600")
          else
            render(UI::Badge::Component.new(text: translation(".optional"), size: :xs))
          end
        end

        def required?
          @required || ActiveModel::Type::Boolean.new.cast(@html_options[:required])
        end

        # The field sits just below its label.
        def input_html_options
          @html_options.merge(class: ["tw:mt-1", @html_options[:class]].compact.join(" "))
        end
      end
    end
  end
end
