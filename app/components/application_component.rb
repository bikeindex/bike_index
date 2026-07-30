# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  include ApplicationComponentHelper

  # e.g. UI::Badge::Component, in a render call or a constant reference
  RENDERED_COMPONENT = /\b(?:[A-Z][A-Za-z0-9]*::)+Component\b/
  # A component's digest usually sits in the markup it covers, so it can't count toward
  # it — committing a new value would otherwise change the value again
  DIGEST_ASSIGNMENT = /^\s*MARKUP_DIGEST = .*$/

  class << self
    # A digest of the markup rendered inside this component's fragment cache, for folding
    # into that cache's key — fragment caches don't digest their own templates, so without
    # this editing markup serves stale HTML. Defaults to the component's own directory;
    # pass globs for markup that isn't a component (an admin table's view partial).
    #
    # Callers commit the result as MARKUP_DIGEST rather than calling this per render:
    # reading every file takes milliseconds, and every process would pay it. The
    # cached_markup_digest shared example recomputes it and fails when the markup has
    # moved on. Nothing here is fast, and nothing needs to be — it only runs in specs.
    def calculated_markup_digest(globs = own_markup)
      contents = markup_files(globs)
        .map { |file| "#{file.relative_path_from(Rails.root)}\n#{file.read.sub(DIGEST_ASSIGNMENT, "")}" }
      Digest::MD5.hexdigest(contents.join("\n"))[0, 12]
    end

    # The files matching globs, plus the markup of every component they render, followed
    # transitively — an admin cell renders Admin::UserCell, which renders
    # Admin::Badges::User, which renders UI::Badge, and any of the three going stale is
    # the same bug.
    def markup_files(globs = own_markup)
      files = glob_markup(globs)
      unscanned = files
      until unscanned.empty?
        unscanned = rendered_component_dirs(unscanned).flat_map { |dir| cached_files("app/components/#{dir}/**/*") } - files
        files += unscanned
      end
      files.sort
    end

    private

    def own_markup
      "app/components/#{name.underscore.delete_suffix("/component")}/**/*"
    end

    # Raises rather than digesting nothing, so a typo in a glob can't quietly stop
    # covering a directory
    def glob_markup(globs)
      Array(globs).flat_map do |glob|
        cached_files(glob).presence || raise(ArgumentError, "No cached markup matched #{glob}")
      end
    end

    # Previews render outside the cache block, so their markup can't go stale — and the
    # components only they render aren't cached markup either
    def cached_files(glob)
      Rails.root.glob(glob).select(&:file?)
        .reject { |file| file.to_s.match?(%r{/(component_preview\.rb|preview/)}) }
    end

    def rendered_component_dirs(files)
      files.flat_map { |file| rendered_in(file) }.uniq
    end

    # Component references resolve the way Ruby resolves them — Registrations::Show::Wrapper
    # renders a bare OrgAdmin::Component, which is registrations/show/org_admin — so walk
    # out from the referencing file's own namespace before falling back to the full path.
    def rendered_in(file)
      namespace = file.dirname.relative_path_from(Rails.root.join("app/components")).to_s.split("/")
      namespace = [] if namespace.first == ".."
      file.read.scan(RENDERED_COMPONENT).filter_map do |reference|
        dir = reference.underscore.delete_suffix("/component")
        namespace.length.downto(0).map { |i| [*namespace[0, i], dir].join("/") }
          .find { |candidate| Rails.root.join("app/components", candidate).directory? }
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
