# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  include ApplicationComponentHelper

  # A digest of the component files rendered inside a fragment cache, for folding into
  # that cache's key. Fragment caches don't digest their own templates, so without this
  # editing markup serves stale HTML until someone remembers to bump a version constant.
  #
  # Memoized only where code doesn't reload, so it costs one glob per boot when deployed.
  # Keying on perform_caching instead would go stale under dev:cache: the reloader
  # ignores template-only edits, so nothing would clear the memo.
  def self.markup_digest(*globs)
    return compute_markup_digest(globs) if Rails.env.local?

    @markup_digest ||= {}
    @markup_digest[globs] ||= compute_markup_digest(globs)
  end

  # Previews render outside the cache block, so their markup can't go stale
  def self.compute_markup_digest(globs)
    files = globs.flat_map { |glob| Rails.root.glob(glob) }
      .select(&:file?).reject { |file| file.to_s.match?(%r{/(component_preview\.rb|preview/)}) }.sort
    Digest::MD5.hexdigest(files.map { |file| "#{file.relative_path_from(Rails.root)}\n#{file.read}" }.join("\n"))[0, 12]
  end
  private_class_method :compute_markup_digest

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
    result = I18n.t(key, **kwargs, scope: scope.compact)

    # Mark _html translations as html_safe (matching Rails' t() helper behavior)
    key.to_s.end_with?("_html") ? result.html_safe : result
  end

  def component_translation_scope
    @component_translation_scope ||= [:components] + component_namespace + [component_name]
  end

  # The component name. For example, SearchResults::BikeBox::Component => BikeBox
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
