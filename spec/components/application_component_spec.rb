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
    # What the tracker misses goes stale with the key still moving for its siblings, so
    # nothing else catches it. A source scan is the oracle here: anything the markup
    # reaches has to be in the tree, via a `# Template Dependency:` comment wherever the
    # tracker can't see the render itself.
    it "digests every component the markup under a cache key reaches" do
      uncovered = cached_components.sort_by(&:name).filter_map do |component|
        missing = reachable_paths(component) - digested_paths(component)
        next if missing.empty?

        "#{component} is missing #{missing.sort.join(", ")}"
      end

      expect(uncovered).to eq []
    end

    # A directive is a claim about what the component renders, and it keeps whatever it
    # names in the digest — so one left behind after its render moved away silently
    # over-invalidates every cache above it
    it "renders every component a Template Dependency names" do
      unreferenced = component_classes.sort_by(&:name).filter_map do |component|
        declared = File.read(component.identifier).scan(/^\s*# Template Dependency: (\S+)/).flatten
        missing = declared - referenced_components(component).map(&:name)
        "#{component} names #{missing.join(", ")}" if missing.any?
      end

      expect(unreferenced).to eq []
    end
  end

  private

  def component_classes
    Rails.application.eager_load!
    ApplicationComponent.descendants.select(&:identifier)
  end

  # The components whose markup digest is folded into a cache key: one keying its own
  # fragment, or one a view names because `skip_digest` left the key to carry it
  def cached_components
    own = component_classes.select { |component| File.read(component.identifier).include?("self.class.cache_digest") }
    named = Rails.root.glob("app/views/**/*.{erb,haml}").flat_map do |file|
      file.read.scan(/\b((?:[A-Z][A-Za-z0-9]*::)+Component)\.cache_digest/).flatten
    end

    (own + named.uniq.filter_map(&:safe_constantize)).uniq
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
  # file's own namespace and let the autoloader answer. Prose naming a component it only
  # points at renders nothing, so comment lines don't count as references.
  def referenced_components(component)
    component_files(component).flat_map { |file|
      namespace = file.dirname.relative_path_from(Rails.root.join("app/components")).to_s.split("/").map(&:camelize)
      markup = file.read.lines.grep_v(/^\s*(#|-#|<%#)/).join
      markup.scan(/\b(?:[A-Z][A-Za-z0-9]*::)+Component\b/).filter_map do |reference|
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
    finder = ViewComponent::CacheDigest.default_finder
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
