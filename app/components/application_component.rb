# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  include ApplicationComponentHelper

  # e.g. UI::Badge::Component, in a render call or a constant reference
  RENDERED_COMPONENT = /\b(?:[A-Z][A-Za-z0-9]*::)+Component\b/
  # A component's digest sits in the markup it covers, so it can't count toward it —
  # committing a new value would otherwise change the value again
  DIGEST_ASSIGNMENT = /^(\s*MARKUP_DIGEST = ).*$/
  private_constant :RENDERED_COMPONENT

  class << self
    # A digest of this component's markup, for folding into the key of a fragment cache
    # it renders inside — fragment caches don't digest their own templates, so without
    # this editing markup serves stale HTML.
    #
    # Callers commit the result as MARKUP_DIGEST rather than calling this per render:
    # reading every file takes milliseconds, and every process would pay it. The
    # cached_markup_digest shared example recomputes it and fails when the markup has
    # moved on, so this only ever runs in specs.
    def calculated_markup_digest
      contents = markup_files
        .map { |file| "#{file.relative_path_from(Rails.root)}\n#{file.read.sub(DIGEST_ASSIGNMENT, "")}" }
      Digest::MD5.hexdigest(contents.join("\n"))[0, 12]
    end

    private

    # This component's own files, plus the markup of every component they render, followed
    # transitively — an admin cell renders Admin::Users::Cell, which renders
    # Admin::Badges::User, which renders UI::Badge, and any of the three going stale is
    # the same bug.
    def markup_files
      files = component_files(self)
      unscanned = files
      until unscanned.empty?
        unscanned = unscanned.flat_map { |file| rendered_in(file) }.uniq
          .flat_map { |component| component_files(component) }.uniq - files
        files += unscanned
      end
      files.sort
    end

    # A component's markup is its sidecar files, which ViewComponent locates from the same
    # identifier. Previews render outside the cache block, so their markup can't go stale —
    # and the components only they render aren't cached markup either.
    def component_files(component)
      Pathname.new(component.identifier).dirname.glob("**/*").select(&:file?)
        .reject { |file| file.to_s.match?(%r{/(component_)?preview(\.rb|/)}) }
    end

    # Component references resolve the way Ruby resolves them — Registrations::Show::Wrapper
    # renders a bare OrgAdmin::Component — so walk out from the referencing file's own
    # namespace and let the autoloader answer.
    def rendered_in(file)
      namespace = file.dirname.relative_path_from(Rails.root.join("app/components")).to_s.split("/").map(&:camelize)
      file.read.scan(RENDERED_COMPONENT).filter_map do |reference|
        namespace.length.downto(0).filter_map { |i| [*namespace[0, i], reference].join("::").safe_constantize }
          .find { |component| component.is_a?(Class) && component < ViewComponent::Base }
      end
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
    ActiveSupport::HtmlSafeTranslation
      .translate(key, **kwargs, scope: (scope || component_translation_scope).compact)
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
