# frozen_string_literal: true

# A table's cells render components that Action View's own template digest can't see, so
# the cell key carries the component's digest of them instead. Hosts define the record a
# row renders; cell_cache_key defaults to the component's digest.
#
# That the digest covers the whole tree is spec/components/application_component_spec.rb.
RSpec.shared_examples "cached_table_cells" do
  include_context :caching_basic
  let(:cell_cache_key) { described_class.cache_digest }

  it "keys each cell to its record and this component's markup digest", :caching do
    # A cell that caches itself (the user cell) writes a fragment of its own, keyed to
    # nothing about this table - so the table's own fragments are the ones carrying its key
    keys = fragments_written { component }.select { it.include?(cell_cache_key) }

    expect(keys.count).to be > 1
    expect(keys).to all(include(cached_record.cache_key_with_version))
  end
end
