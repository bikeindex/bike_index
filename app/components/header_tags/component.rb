# frozen_string_literal: true

module HeaderTags
  class Component < ApplicationComponent
    def initialize(page_title: nil, page_obj: nil, controller_name:, controller_namespace: nil, action_name:)
      @page_title = page_title || auto_title_for(controller_name:, controller_namespace:, action_name:)

      @controller_name = controller_name
      @controller_namespace = controller_namespace
      @action_name = action_name
    end

    private

    def translation_title(location: nil, translation_args: default_translation_args)
      location ||= "meta_titles.#{page_id}"
      t(location, **translation_args)
    end

    def auto_title
      return translation_title if translation_title.present?

      [auto_namespace_title, auto_controller_and_action_title].compact.join(" ")
    end

    def default_translation_args
      return {default: ""} unless controller_namespace == "organized"

      {default: "", organization: current_organization.short_name}
    end
  end
end
