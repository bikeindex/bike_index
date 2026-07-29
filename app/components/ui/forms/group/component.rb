# frozen_string_literal: true

module UI
  module Forms
    module Group
      class Component < ApplicationComponent
        # Pass a block (a UI::Forms::Combobox, Select, TextEditor...) and it renders in
        # place of the input -- `kind` is then unused. Without a form_builder that block
        # is the only valid shape: the label falls back to label_tag, so it points at
        # whatever the block renders with the attribute's id.
        def initialize(attribute:, form_builder: nil, kind: :text_field, label_text: nil, required: false,
          wrapper_class: "tw:mb-4", html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = Input::Component.validate_kind!(kind)
          @label_text = label_text || attribute.to_s.humanize
          @required = required
          @wrapper_class = wrapper_class
          @html_options = html_options
        end

        def before_render
          raise ArgumentError, "pass form_builder, or a content block" if @form_builder.nil? && !content?
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
