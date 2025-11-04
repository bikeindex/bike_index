# frozen_string_literal: true

module Badge::BikeHiddenAdminExplanation
  class ComponentPreview < ApplicationComponentPreview
    # @group Hidden Variants
    def user_hidden
      render(Badge::BikeHiddenAdminExplanation::Component.new(bike: Bike.with_user_hidden.where(user_hidden: true).last))
    end

    def example
      render(Badge::BikeHiddenAdminExplanation::Component.new(bike: Bike.example.last))
    end

    def spam
      render(Badge::BikeHiddenAdminExplanation::Component.new(bike: Bike.spam.last))
    end

    def deleted
      render(Badge::BikeHiddenAdminExplanation::Component.new(bike: Bike.only_deleted.last))
    end

    def all_of_em
      bike = Bike.new(example: true, likely_spam: true, user_hidden: true, deleted_at: Time.current - 1.hour)

      render(Badge::BikeHiddenAdminExplanation::Component.new(bike:))
    end
  end
end
