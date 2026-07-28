# frozen_string_literal: true

# Fragment caches don't digest the templates inside them, so editing that markup
# serves stale HTML until the component's CACHE_VERSION is bumped by hand. This
# digests the components rendered inside the cache block and fails when they change
# without a bump, rewriting the checkpoint once the version is bumped — a run is only
# green with the current checkpoint committed.
#
# Pass the component directories (relative to app/components) rendered inside the
# cache block; defaults to the described component's own directory. Components
# rendered by those components are missed, so the guard nags rather than proves.
RSpec.shared_examples "cache_version_checkpoint" do |cached_component_dirs = nil|
  let(:component_dir) { described_class.name.underscore.delete_suffix("/component") }
  let(:component_dirs) { Array(cached_component_dirs || component_dir) }
  let(:checkpoint_path) { Rails.root.join("spec/components", component_dir, "cache_version_checkpoint.yml") }
  let(:checkpoint) { checkpoint_path.exist? ? YAML.safe_load_file(checkpoint_path) : {} }
  # Previews render outside the cache block, so their markup can't go stale
  let(:cached_files) do
    component_dirs.flat_map { |dir| Rails.root.glob("app/components/#{dir}/**/*") }
      .select(&:file?).reject { |file| file.to_s.match?(%r{/(component_preview\.rb|preview/)}) }.sort
  end
  let(:files_digest) do
    Digest::SHA256.hexdigest(cached_files.map { |file| "#{file.relative_path_from(Rails.root)}\n#{file.read}" }.join("\n"))
  end

  it "bumps CACHE_VERSION when the cached components change" do
    expect(cached_files.count).to be > 1 # a renamed or mistyped directory shouldn't silently pass
    next if checkpoint["files_digest"] == files_digest

    expect(described_class::CACHE_VERSION).to_not eq(checkpoint["cache_version"]),
      "#{component_dirs.join(", ")} changed but #{described_class}::CACHE_VERSION is still " \
      "#{described_class::CACHE_VERSION.inspect} — bump it, then re-run this spec"

    checkpoint_path.write("# Written by the cache_version_checkpoint shared example\n" +
      {"cache_version" => described_class::CACHE_VERSION, "files_digest" => files_digest}.to_yaml)
    raise "Rewrote #{checkpoint_path.relative_path_from(Rails.root)} for #{described_class::CACHE_VERSION} — commit it"
  end
end
