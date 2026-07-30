# frozen_string_literal: true

# Fragment caches don't digest the templates inside them, so editing that markup serves
# stale HTML until the cache key changes. Cached callers fold in MARKUP_DIGEST, a digest
# of the CACHED_MARKUP they render inside the cache block plus everything that markup
# renders transitively. This recomputes it and fails when the markup has moved on, so
# the digest is committed rather than read from disk on every render.
RSpec.shared_examples "cached_markup_digest" do
  let(:cached_markup) { described_class::CACHED_MARKUP }

  it "has the current digest of its cached markup committed" do
    expect(ApplicationComponent.markup_files(cached_markup).count).to be > 1
    expect(described_class::MARKUP_DIGEST).to eq(ApplicationComponent.markup_digest(cached_markup)),
      "#{described_class}'s cached markup changed — set its MARKUP_DIGEST to " \
      "#{ApplicationComponent.markup_digest(cached_markup).inspect}"
  end
end
