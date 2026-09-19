# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponent, type: :component do
  describe "sidecar translations" do
    # ViewComponent digests the sidecars in a component's own directory, so a sidecar one
    # level up contributes to no digest and its copy can go stale inside a fragment cache
    it "keeps every sidecar in a directory with the component that reads it" do
      orphaned = Rails.root.glob("app/components/**/component.*.yml")
        .reject { |file| file.dirname.join("component.rb").exist? }
        .map { |file| file.relative_path_from(Rails.root).to_s }

      expect(orphaned).to eq []
    end
  end

  describe "cache digests" do
    # ViewComponent's tracker reads one shape, a constant directly after `render`, so a
    # component rendered through a local or a method, built into a collection, or
    # referenced for a constant drops out of the digest and goes stale inside every cache
    # above it — with the key still moving for its siblings, so nothing else catches it.
    # A source scan finds what the tracker misses; the fix is a `# Template Dependency:`
    # comment naming the full class on the component that renders it.
    it "digests every component the markup under a cache key reaches" do
      uncovered = cached_components.sort_by(&:name).filter_map do |component|
        missing = reachable_paths(component) - digested_paths(component)
        next if missing.empty?

        "#{component} is missing #{missing.sort.join(", ")}"
      end

      expect(uncovered).to eq []
    end
  end

  private

  # The components whose markup digest is folded into a cache key: one keying its own
  # fragment, or one a view names because `skip_digest` left the key to carry it
  def cached_components
    files = Rails.root.glob("app/components/**/component.rb") + Rails.root.glob("app/views/**/*.{erb,haml}")
    files.flat_map { |file| cached_components_in(file) }.uniq
  end

  def cached_components_in(file)
    source = file.read
    return [] unless source.include?("cache_digest")

    named = source.scan(/\b((?:[A-Z][A-Za-z0-9]*::)+Component)\.cache_digest/).flatten.filter_map(&:safe_constantize)
    return named unless source.include?("self.class.cache_digest")

    # Read from the file's own module nesting, so ui/ comes back as UI:: rather than Ui::
    [[*source.scan(/^\s*module ([A-Z]\w*)/).flatten, "Component"].join("::").safe_constantize, *named].compact
  end

  # Everything this component's markup can reach by source reference, followed the way
  # the digest is meant to follow it
  def reachable_paths(component)
    found = [component]
    unscanned = found
    until unscanned.empty?
      unscanned = unscanned.flat_map { |scanned| referenced_components(scanned) }.uniq - found
      found += unscanned
    end
    (found - [component]).map(&:virtual_path)
  end

  # References resolve the way Ruby resolves them, so walk out from the referencing
  # file's own namespace and let the autoloader answer
  def referenced_components(component)
    component_files(component).flat_map { |file|
      namespace = file.dirname.relative_path_from(Rails.root.join("app/components")).to_s.split("/").map(&:camelize)
      file.read.scan(/\b(?:[A-Z][A-Za-z0-9]*::)+Component\b/).filter_map do |reference|
        namespace.length.downto(0).filter_map { |i| [*namespace[0, i], reference].join("::").safe_constantize }
          .find { |found| found.is_a?(Class) && found < ViewComponent::Base }
      end
    }.uniq - [component]
  end

  # Previews render outside the cache block, so what only they render isn't cached markup
  def component_files(component)
    Pathname.new(component.identifier).dirname.glob("**/*").select(&:file?)
      .reject { |file| file.to_s.match?(%r{/(component_)?preview(\.rb|/)}) }
  end

  # What Action View's digest tree actually reaches, which is what the digest covers
  def digested_paths(component)
    prefix = "#{ViewComponent::CacheDigest::VIRTUAL_PATH_PREFIX}/"
    finder = ActionView::LookupContext.new(ActionController::Base.view_paths)
    tree = ActionView::Digestor.tree(ViewComponent::CacheDigest.virtual_path_for(component), finder)
    flattened_dependencies(tree.to_dep_map).filter_map { |name| name.delete_prefix(prefix) if name.start_with?(prefix) }
  end

  # to_dep_map nests a hash per node that has children, and a bare name per leaf
  def flattened_dependencies(dependencies)
    Array.wrap(dependencies).flat_map do |dependency|
      next dependency unless dependency.is_a?(Hash)

      dependency.flat_map { |name, children| [name, *flattened_dependencies(children)] }
    end
  end
end
