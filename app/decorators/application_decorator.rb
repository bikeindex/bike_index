class ApplicationDecorator < Draper::Decorator 
  delegate_all
  include ActionView::Helpers::NumberHelper

  def self.collection_decorator_class
    PaginatingDecorator
  end

  def ass_name(association, extra = '')
    ass = object.send(association, name)
    [ass.name, extra].reject(&:blank?).join(' ') if ass.present?
  end

  def attr_list_item(desc = nil, title, with_colon: false)
    return nil unless desc.present?
    title = "#{title}:" if with_colon
    html = h.content_tag(:span, title, class: 'attr-title')
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
    self.dl_list_item(description, title)
  end

  def dl_from_attribute_othered(attribute, title = nil)
    description = ass_name(attribute)
    return nil unless description
    if description == "Other style"
      other = if_present("#{attribute}_other")
      description = other if other.present?
    end
    title = attribute.titleize unless title.present?
    self.dl_list_item(description, title)
  end

  def if_present(attribute, action = nil)
    if object.send(attribute).present?
      return action if action.present?
      object.send(attribute)
    end
  end

  def twitterable(user)
    if user.show_twitter and user.twitter
     h.link_to 'Twitter', "https://twitter.com/#{user.twitter}"
    end
  end

  def websiteable(user)
    if user.show_website and user.website
      h.link_to 'Website', user.website
    end
  end

  def show_twitter_and_website(user)
    if twitterable(user) or websiteable(user)
      html = ""
      if twitterable(user)
        html << twitterable(user)
        html << " and #{websiteable(user)}" if websiteable(user)
      else
        html << websiteable(user)
      end
      html.html_safe
    end
  end

  def short_address(item)
    return nil unless item.country
    html = "#{item.city}"
    html << ", #{item.state.abbreviation}" if item.state.present?
    html << " - #{item.country.iso}"
    html
  end

  def display_phone(p=object.phone)
    if p[/\+/]
      phone = number_to_phone(p.gsub(/\+\d*/,''), country_code: p[/\A.\d*/].gsub('+',''), delimiter: ' ' )
    else
      phone = number_to_phone(p, delimiter: ' ')
    end
    phone
  end

end