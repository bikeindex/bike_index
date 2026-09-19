# frozen_string_literal: true

# A digest of some markup, for folding into the key of a fragment cache that covers it.
#
# Fragment caches don't digest what's inside them. Rails' template digest follows a view's
# partials but stops at `render Foo::Component.new`, and never reaches a component's markup
# at all — either way, editing markup serves stale HTML.
#
# Both homes commit the value rather than calculating it per render, since every process
# would pay the file reads: a component assigns MARKUP_DIGEST and folds the constant into
# its cache key, and a template carries the same assignment in a comment, where rewriting
# it moves the template digest Rails already folds in. `bin/update_markup_digests` rewrites
# every stale one, and the spec fails when markup has moved on.
module MarkupDigest
  extend Functionable

  # `MARKUP_DIGEST = "…"`, bare in a .rb, inside `<%# %>` in an .erb, after `-#` in a .haml
  ASSIGNMENT = /^(?<before>.*\bMARKUP_DIGEST = )"(?<digest>[^"]*)"(?<after>.*)$/
  # e.g. UI::Badge::Component, in a render call or a constant reference
  RENDERED_COMPONENT = /\b(?:[A-Z][A-Za-z0-9]*::)+Component\b/
  # e.g. `render partial: "/shared/google_ad"`, or `render "shared/google_ad"`
  RENDERED_PARTIAL = /\brender[\s(]+(?:partial:\s*)?["']\/?([a-z0-9_]+(?:\/[a-z0-9_]+)*)["']/
  COMPONENTS_ROOT = Rails.root.join("app/components")
  private_constant :RENDERED_COMPONENT, :RENDERED_PARTIAL, :COMPONENTS_ROOT

  def calculate(file)
    contents = markup_files(file)
      .map { |markup| "#{markup.relative_path_from(Rails.root)}\n#{markup.read.sub(ASSIGNMENT, "")}" }
    Digest::MD5.hexdigest(contents.join("\n"))[0, 12]
  end

  def committed(file) = file.read[ASSIGNMENT, "digest"]

  # Every file that commits a digest: a component, or a template whose fragment cache
  # covers markup Rails' own template digest can't see
  def files
    (Rails.root.glob("app/components/**/*.rb") + Rails.root.glob("app/views/**/*.{erb,haml}"))
      .select { |file| file.read.match?(ASSIGNMENT) }.sort
  end

  # The digest written, or nil when the committed one was already current
  def update(file)
    digest = calculate(file)
    return nil if committed(file) == digest

    file.write(file.read.sub(ASSIGNMENT, "\\k<before>\"#{digest}\"\\k<after>"))
    digest
  end

  # This file's own markup, plus the markup of everything it renders, followed transitively
  # — an admin cell renders Pages::Admin::Users::Cell, which renders
  # Atoms::Admin::Badges::User, which renders UI::Badge, and any of the three going stale
  # is the same bug
  def markup_files(file)
    covered = sidecar_files(file)
    unscanned = covered
    until unscanned.empty?
      unscanned = unscanned.flat_map { |scanned| rendered_files(scanned) }.uniq - covered
      covered += unscanned
    end
    covered.sort
  end

  #
  # private below here
  #

  # A component's markup is its sidecar files, which ViewComponent locates from the same
  # directory; a template's is the template. Previews render outside the cache block, so
  # their markup can't go stale — and the components only they render aren't cached markup
  # either.
  def sidecar_files(file)
    return [file] unless component_file?(file)

    file.dirname.glob("**/*").select(&:file?)
      .reject { |sidecar| sidecar.to_s.match?(%r{/(component_)?preview(\.rb|/)}) }
  end

  def rendered_files(file)
    source = file.read
    rendered_components(source, file).flat_map { |component| sidecar_files(component) } +
      rendered_partials(source, file)
  end

  # Component references resolve the way Ruby resolves them — Pages::Registrations::Show::Wrapper
  # renders a bare OrgAdmin::Component — so walk out from the referencing file's own
  # namespace and let the autoloader answer. A template outside app/components has no
  # namespace of its own to walk, and names components in full.
  def rendered_components(source, file)
    namespace = component_namespace(file)
    source.scan(RENDERED_COMPONENT).filter_map do |reference|
      namespace.length.downto(0).filter_map { |i| [*namespace[0, i], reference].join("::").safe_constantize }
        .find { |component| component.is_a?(Class) && component < ViewComponent::Base }
    end.map { |component| Pathname.new(component.identifier) }
  end

  def component_namespace(file)
    return [] unless component_file?(file)

    file.dirname.relative_path_from(COMPONENTS_ROOT).to_s.split("/").map(&:camelize)
  end

  def component_file?(file) = file.to_s.start_with?(COMPONENTS_ROOT.to_s)

  # A partial name resolves against app/views, unless it names no directory of its own —
  # then it's the directory of the template rendering it
  def rendered_partials(source, file)
    source.scan(RENDERED_PARTIAL).flatten.uniq.flat_map do |name|
      directory = name.include?("/") ? Rails.root.join("app/views", File.dirname(name)) : file.dirname
      directory.glob("_#{File.basename(name)}.*")
    end
  end

  conceal :sidecar_files, :rendered_files, :rendered_components, :component_namespace,
    :component_file?, :rendered_partials
end
