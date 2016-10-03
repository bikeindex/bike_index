shared_context :page_content_values do
  # Find title tag in response body
  # grab first matching group of values between brackets ;)
  let(:title) { response.body[/<title[^>]*>([^<]*)/, 1] }
end
