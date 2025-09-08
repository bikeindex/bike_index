module HtmlContentHelpers
  def whitespace_normalized_body_text(content = nil)
    content ||= response.body
    doc = Nokogiri::HTML::DocumentFragment.parse(content.split("</head>").last)
    # Remove all script and style elements completely
    doc.css("script, style").remove
    # Spaces and also non-breaking spaces
    doc.text.strip.gsub(/\s+/, " ").tr("\u00A0", " ")
  end
end
