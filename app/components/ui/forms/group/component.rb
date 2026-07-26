# frozen_string_literal: true

module UI
  module Forms
    module Group
      class Component < ApplicationComponent
        # label_suffix: rendered markup shown after the label text (e.g. an optional badge or required *)
        def initialize(form_builder:, attribute:, kind: :text_field, label_text: nil, label_suffix: nil,
          wrapper_class: "tw:mb-4", choices: nil, select_options: {}, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = kind.to_sym
          @label_text = label_text || attribute.to_s.humanize
          @label_suffix = label_suffix
          @wrapper_class = wrapper_class
          @choices = choices
          @select_options = select_options
          @html_options = html_options
        end

        private

        def label_content
          safe_join([@label_text, @label_suffix].compact, " ")
        end

        # The field sits just below its label.
        def input_html_options
          @html_options.merge(class: ["tw:mt-1", @html_options[:class]].compact.join(" "))
        end
      end
    end
  end
end
