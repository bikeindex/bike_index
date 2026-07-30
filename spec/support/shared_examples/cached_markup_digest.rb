# frozen_string_literal: true

# Fragment caches don't digest the templates inside them, so editing that markup would
# serve stale HTML. The cached components fold ApplicationComponent.markup_digest over
# their CACHED_MARKUP globs into the cache key, which invalidates on its own — this just
# checks that wiring is live, so a mistyped glob can't silently stop covering a directory.
RSpec.shared_examples "cached_markup_digest" do |sample_template|
  let(:cached_markup) { Array(described_class::CACHED_MARKUP) }
  let(:template) { Rails.root.join(sample_template) }

  # A method, not a let — the point is to recompute it either side of the edit
  def markup_digest
    described_class.markup_digest(*Array(described_class::CACHED_MARKUP))
  end

  it "covers the cached markup, and not previews" do
    expect(cached_markup).to be_present
    expect(template).to exist # a moved template shouldn't silently stop being covered
    expect(markup_digest).to be_present

    original = template.read
    expect { template.write("#{original}\n<!-- edited -->\n") }.to change { markup_digest }
  ensure
    template&.write(original) if original
  end
end
