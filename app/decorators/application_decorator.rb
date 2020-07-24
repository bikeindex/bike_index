# NB: Decorators are deprecated in this project.
#     Use Helper methods for view logic, consider incrementally refactoring
#     existing view logic from decorators to view helpers.
class ApplicationDecorator < Draper::Decorator
  delegate_all
  include ActionView::Helpers::NumberHelper

  def self.collection_decorator_class
    PaginatingDecorator
  end

  def ass_name(association, extra = "")
    assoc = object.public_send(association)
    return if assoc.blank?
    [assoc.name, extra].reject(&:blank?).join(" ")
  end

  def attr_list_item(desc = nil, title, with_colon: false)
    return nil unless desc.present?
    title = "#{title}:" if with_colon
    html = h.content_tag(:span, title, class: "attr-title")
    h.content_tag(:li, html + desc)
  end

  def dl_list_item(dd = nil, dt)
    return nil unless dd.present?
    html = h.content_tag(:dt, dt)
    html << h.content_tag(:dd, dd)
    html.html_safe
  end

  def dl_from_attribute(attribute, title = nil)
    description = if_present(attribute)
    return nil unless description
    title = attribute.titleize unless title.present?
    dl_list_item(description, title)
  end

  def dl_from_attribute_othered(attribute, title = nil)
    description = ass_name(attribute)
    return nil unless description
    if description == "Other style"
      other = if_present("#{attribute}_other")
      description = other if other.present?
    end
    title = attribute.titleize unless title.present?
    dl_list_item(description, title)
  end

  def if_present(attribute, action = nil)
    if object.send(attribute).present?
      return action if action.present?
      object.send(attribute)
    end
  end
end
