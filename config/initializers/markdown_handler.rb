module MarkdownHandler
  def self.erb
    @erb ||= ActionView::Template.registered_template_handler(:erb)
  end

  def self.call(template, source)
    compiled_source = erb.call(template, source)
    "begin; output = #{compiled_source}; " \
    "output = output.to_str if output.respond_to?(:to_str); " \
    "Kramdown::Document.new(output.to_s, auto_ids: false).to_html; end"
  end
end

ActionView::Template.register_template_handler :md, MarkdownHandler
ActionView::Template.register_template_handler :markdown, MarkdownHandler
