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

        def call
          tag.code(@text, class: classes)
        end

        private

        def classes
          ["tw:text-pink-600 tw:dark:text-pink-400", (@small ? "tw:text-xs" : "tw:text-sm"), (@word_break ? "tw:wrap-break-word" : "tw:break-keep")]
        end
      end
    end
  end
end
