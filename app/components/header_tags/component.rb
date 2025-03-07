# frozen_string_literal: true

module HeaderTags
  class Component < ApplicationComponent
    DEFAULT_IMAGE = "/opengraph.png"
    DEFAULT_TWITTER = "@bikeindex"

    def initialize(page_title: nil, page_description: nil, page_obj: nil, updated_at: nil, organization_name: nil,
                   controller_name:, controller_namespace: nil, action_name:, request_url:, language:)

      # TODO: Do any pages need a query string?
      @page_url = request_url.split('?').first
      @language = language

      @controller_action = "#{controller_name}_#{action_name}"

      if page_obj.is_a?(Bike) || page_obj.is_a?(BikeVersion)
        assign_bike_attrs(page_obj)
      elsif page_obj.is_a?(Blog)
        assign_blog_attrs(page_obj)
      else

      end

      # Can we drop assigning controller_name? only required for atom
      @controller_name = controller_name
      @action_name = action_name
    end

    private

    def bike_index_description
      "Default description, but translated"
    end

    def page_image
      @page_image || DEFAULT_IMAGE
    end

    def twitter_creator
      @twitter_creator || DEFAULT_TWITTER
    end

    def og_updated_property
      @meta_type == "article" ? "article:modified_time" : "og:updated_time"
    end

    def url_canonical
      @url_canonical || @page_url
    end

    def page_json_ld
      # ... eventually might want to use Vehicle, but currently would use no properties
      json_ld_type = if @meta_type == "article"
        @controller_action == 'news_show' ? 'BlogPosting' : 'Article'
      else
        'WebPage'
      end
      {
        "@context" => "http://schema.org",
        "@type" => json_ld_type,
        "image" => @page_image,
        "url" => @page_url,
        "headline" => @page_title,
        "alternativeHeadline" => (@secondary_title.present? ? @secondary_title : @page_description)
      }.merge(@published_at.present? ? {"datePublished" => @published_at} : {})
       .merge(@updated_at.present? ? {"dateModified" => @updated_at} : {})
    end

    def assign_bike_attrs(bike)
      @updated_at = bike.updated_at.utc.iso8601(0)
    end

    def assign_blog_attrs(blog)
      @updated_at = blog.updated_at.utc.iso8601(0)
      @published_at = blog.updated_at.utc.iso8601(0)
      @meta_type = "article"
      @page_title ||= blog.title
      @page_description ||= blog.description
      @secondary_title = blog.secondary_title if blog.secondary_title.present?
      @page_image = if blog.index_image.present?
        blog.index_image_lg
      elsif blog.public_images.any?
        blog.public_images.last.image_url
      end
      @url_canonical = blog.canonical_url if blog.canonical_url?
      return unless blog.user.present?

      @twitter_creator = "@#{blog.user.twitter}" if blog.user.twitter
      @author = "/users/#{blog.user&.to_param}"
    end

    # def assign_page_title_and_description(page_title:, controller_name:, controller_namespace:, action_name:, current_organization:)
    #   translation_args = {}
    #   if current_organization.present?
    #     translation_args.merge!(organization: current_organization.short_name)
    #   end
    #   #
    #   translation_location = if @controller_action == "welcome_choose_registration"
    #     "bikes_new"
    #   else
    #     @controller_action
    #   end

    #   @page_title = translation_title(translation_location, translation_args)
    #   @page_description = translation_description(translation_location, translation_args)
    #   # SPECIAL_CONTROLLERS = %w[bikes welcome my_accounts news users landing_pages].freeze
    #   # @page_title = page_title #|| auto_title_for(controller_name:, controller_namespace:, action_name:)
    # end

    # def translation_title(translation_location, translation_args = {})
    #   t("meta_titles.#{translation_location}", **translation_args)
    # end

    # def translation_description(translation_location, translation_args = {})
    #   t("meta_descriptions.#{translation_location}", **translation_args)
    # end

    # def auto_title_for(controller_name:, controller_namespace:, action_name:)
    #   return translation_title if translation_title.present?

    #   [auto_namespace_title, auto_controller_and_action_title].compact.join(" ")
    # end

    # def auto_controller_and_action_title
    #   case action_name
    #   when "index"
    #     controller_name.humanize
    #   when "new", "edit", "show", "create"
    #     "#{auto_action_name_title} #{controller_name.humanize.singularize.downcase}"
    #   else
    #     action_name.humanize
    #   end
    # end

    # def auto_namespace_title
    #   if controller_namespace == "admin"
    #     "🧰"
    #   elsif controller_namespace == "organized"
    #     current_organization.short_name
    #   end
    # end

    # def auto_action_name_title
    #   {
    #     new: "New",
    #     edit: "Edit",
    #     show: "View",
    #     create: "Created"
    #   }.as_json.freeze[action_name]
    # end
  end
end
