# frozen_string_literal: true

module Messages::Threads
  class Component < ApplicationComponent
    def initialize(marketplace_messages:, current_user:)
      @marketplace_messages = marketplace_messages
      @current_user = current_user
    end

    private
  end
end
