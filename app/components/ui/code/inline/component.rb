# frozen_string_literal: true

module UI
  module Code
    module Inline
      class Component < ApplicationComponent
        def initialize(text:, small: false, word_break: true)
          @text = text
          @small = small
          @word_break = word_break
        end

        def call = tag.code(@text, class: classes)

        private

        # The resets beat bootstrap's `code` rule, on pages loading the legacy stylesheet
        def classes = ["tw:rounded-none tw:bg-transparent tw:p-0 tw:text-pink-600 tw:dark:text-pink-400", @small ? "tw:text-xs" : "tw:text-sm", @word_break ? "tw:wrap-break-word" : "tw:break-keep"]
      end
    end
  end
end
