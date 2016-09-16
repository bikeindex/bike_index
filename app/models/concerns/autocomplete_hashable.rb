module AutocompleteHashable
  extend ActiveSupport::Concern

  def autocomplete_result_hash
    hash = autocomplete_hash.dup
    hash.merge(hash.delete('data'))
  end
end
