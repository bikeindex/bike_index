module JsonHelpers
  def json_headers
    { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
  end

  def json_result
    return @json_result if defined?(@json_result)
    r = JSON.parse(response.body)
    @json_result = r.is_a?(Hash) ? r.with_indifferent_access : r
  end
end
