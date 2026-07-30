# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  include ApplicationComponentHelper

  COMPONENT_MARKUP = "app/components/**/*"

  class << self
    # A digest of every component's markup, for folding into a fragment cache key.
    # Fragment caches don't digest their own templates, so without this editing markup
    # serves stale HTML until someone remembers to bump a version constant. Pass
    # extra_markup for cached markup living outside app/components (an admin table
    # partial). Digesting the whole tree is what keeps this honest: cells render
    # components that render components, so a per-caller list of directories quietly
    # stops covering the ones it doesn't reach.
    #
    # Memoized only where code doesn't reload — the dev reloader ignores template-only
    # edits, so a memo there would go stale under dev:cache.
    def markup_digest(extra_markup = nil)
      return "nocache" unless ActionController::Base.perform_caching
      return compute_markup_digest(extra_markup) if Rails.env.local?

      (@markup_digests ||= {})[extra_markup] ||= compute_markup_digest(extra_markup)
    end

    def markup_files(extra_markup = nil)
      [COMPONENT_MARKUP, *extra_markup].flat_map { |glob| glob_markup(glob) }.sort
    end

    private

    def compute_markup_digest(extra_markup)
      contents = markup_files(extra_markup).map { |file| "#{file.relative_path_from(Rails.root)}\n#{file.read}" }
      Digest::MD5.hexdigest(contents.join("\n"))[0, 12]
    end

    # Raises rather than digesting nothing, so a typo in a glob can't quietly stop
    # covering a directory
    def glob_markup(glob)
      Rails.root.glob(glob).select(&:file?)
        # Previews render outside the cache block, so their markup can't go stale
        .reject { |file| file.to_s.match?(%r{/(component_preview\.rb|preview/)}) }
        .presence || raise(ArgumentError, "No cached markup matched #{glob}")
    end
  end

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
