module HtmlContentHelpers
  def whitespace_normalized_body_text(content = nil)
    content ||= response.body
    doc = Nokogiri::HTML::DocumentFragment.parse(content.split("</head>").last)
    # Remove all script and style elements completely
    doc.css("script, style").remove
    doc.text.strip.gsub(/\s+/, " ")
  end
end
