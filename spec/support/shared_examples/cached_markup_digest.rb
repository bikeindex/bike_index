# frozen_string_literal: true

# Fragment caches don't digest the templates inside them, so editing that markup serves
# stale HTML until the cache key changes. Cached components fold in MARKUP_DIGEST, a
# digest of their own markup plus everything that markup renders transitively. This
# recomputes it and fails when the markup has moved on, so the digest is committed
# rather than read from disk on every render.
#
# `bin/update_component_digests` rewrites every stale digest.
RSpec.shared_examples "cached_markup_digest" do
  it "has the current digest of its cached markup committed" do
    calculated = described_class.calculated_markup_digest
    expect(described_class::MARKUP_DIGEST).to eq(calculated),
      "#{described_class}'s cached markup changed — run bin/update_component_digests, " \
      "or set its MARKUP_DIGEST to #{calculated.inspect}"
  end
end
