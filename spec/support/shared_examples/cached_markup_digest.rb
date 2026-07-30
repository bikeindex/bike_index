# frozen_string_literal: true

# Fragment caches don't digest the templates inside them, so editing that markup serves
# stale HTML until the cache key changes. Cached callers fold in MARKUP_DIGEST, a digest
# of the markup they render inside the cache block plus everything that markup renders
# transitively. This recomputes it and fails when the markup has moved on, so the digest
# is committed rather than read from disk on every render.
#
# Components digest their own directory; pass globs for markup that isn't a component.
RSpec.shared_examples "cached_markup_digest" do |cached_markup = nil|
  let(:calculated) do
    cached_markup.present? ? ApplicationComponent.calculated_markup_digest(cached_markup) : described_class.calculated_markup_digest
  end

  it "has the current digest of its cached markup committed" do
    expect(described_class::MARKUP_DIGEST).to eq(calculated),
      "#{described_class}'s cached markup changed — set its MARKUP_DIGEST to #{calculated.inspect}"
  end
end
