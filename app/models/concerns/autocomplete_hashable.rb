module AutocompleteHashable
  extend ActiveSupport::Concern

  def autocomplete_result_hash
    autocomplete_hash.except(:data).merge(autocomplete_hash[:data]).as_json
  end
end
