# frozen_string_literal: true

# A table's cells render components that Action View's own template digest can't see, so
# the row key carries the component's digest of them instead. Hosts define the record a
# row renders and the prefix the component builds its cache_key from.
#
# That the digest covers the whole tree is spec/components/application_component_spec.rb.
RSpec.shared_examples "cached_table_rows" do
  include_context :caching_basic

  it "keys each row to its record and this component's markup digest", :caching do
    keys = fragments_written { component }

    expect(keys.count).to eq 1
    expect(keys.first).to include("#{row_cache_prefix}#{described_class.cache_digest}",
      cached_record.cache_key_with_version)
  end
end
