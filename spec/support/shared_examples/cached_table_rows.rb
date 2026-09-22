# frozen_string_literal: true

# A table's cells render components that Action View's own template digest can't see, so
# the row key carries the component's digest of them instead. Hosts define the record a
# row renders; row_cache_key defaults to the component's digest.
#
# That the digest covers the whole tree is spec/components/application_component_spec.rb.
RSpec.shared_examples "cached_table_rows" do
  include_context :caching_basic
  let(:row_cache_key) { described_class.cache_digest }

  it "keys each row to its record and this component's markup digest", :caching do
    # The user cell writes a fragment of its own, keyed to nothing about this table
    keys = fragments_written { component }.select { it.include?(row_cache_key) }

    expect(keys.count).to eq 1
    expect(keys.first).to include(row_cache_key,
      cached_record.cache_key_with_version)
  end
end
