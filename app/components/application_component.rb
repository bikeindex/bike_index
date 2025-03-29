# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  def raise_if_invalid_value!(attribute, value, options = {})
    return if options.include?(value)

    raise ArgumentError, "Invalid #{attribute}: #{value}. Must be one of: #{options.join(", ")}"
  end

  def component_list_item(desc, title)
    return nil unless desc.present?
    content_tag(:li) do
      content_tag(:strong, "#{title}: ", class: "") +
        content_tag(:span, desc)
    end
  end

  private

  # Wrap `I18n.translate` for use in components, abstracting away
  # scope-setting.
  #
  # NOTE: There is an equivalent method in ControllerHelpers#translation
  #
  # :components
  # > [component_namespace] (possibly none)
  # > [component_name]
  #
  # Either the component method or the entire scope can be overridden via the
  # corresponding keyword args, the latter taking precedence if both are
  # provided.
  #
  # See specs for component_translation_scope in Search::Form::Component
  def translation(key, scope: nil, **kwargs)
    scope ||= component_translation_scope

    I18n.t(key, **kwargs, scope: scope.compact)
  end

  def component_translation_scope
    @component_translation_scope ||= [:components] + component_namespace + [component_name]
  end

  # The component name. For example, Search::BikeBox::Component => BikeBox
  def component_name
    set_name_and_namespace unless defined?(@component_name)
    @component_name
  end

  def component_namespace
    set_name_and_namespace unless defined?(@component_namespace)
    @component_namespace
  end

  def set_name_and_namespace
    arr = self.class.name.split("::")[0..-2].map { |i| i.underscore.downcase }
    @component_name = arr.pop
    @component_namespace = arr
  end
end
