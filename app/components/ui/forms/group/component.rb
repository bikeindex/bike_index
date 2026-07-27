# frozen_string_literal: true

module UI
  module Forms
    module Group
      class Component < ApplicationComponent
        # Without a form_builder (a form_tag form) the label points at whatever the
        # content block renders with the attribute's id.
        def initialize(attribute:, form_builder: nil, kind: :text_field, label_text: nil, required: false,
          wrapper_class: "tw:mb-4", html_options: {})
          @kind = kind.to_sym
          raise ArgumentError, "pass form_builder, or kind: :content_block" if form_builder.nil? && @kind != :content_block

          @form_builder = form_builder
          @attribute = attribute
          @label_text = label_text || attribute.to_s.humanize
          @required = required
          @wrapper_class = wrapper_class
          @html_options = html_options
        end

        private

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
          if required?
            tag.span("*", class: "tw:text-red-600")
          else
            render(UI::Badge::Component.new(text: translation(".optional"), size: :xs))
          end
        end

        def required?
          @required || ActiveModel::Type::Boolean.new.cast(@html_options[:required])
        end
      end
    end
  end
end
