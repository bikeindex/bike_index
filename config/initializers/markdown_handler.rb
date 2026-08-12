module MarkdownHandler
  def self.erb
    @erb ||= ActionView::Template.registered_template_handler(:erb)
  end

  # ERB compiles to several statements; begin/end groups them so to_html receives the last one
  def self.call(template, source)
    "MarkdownHandler.to_html(begin;#{erb.call(template, source)}\nend)"
  end

  def self.to_html(output)
    Kramdown::Document.new(output.to_s, auto_ids: false).to_html
  end
end

ActionView::Template.register_template_handler :md, MarkdownHandler
ActionView::Template.register_template_handler :markdown, MarkdownHandler
