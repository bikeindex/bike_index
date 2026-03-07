# frozen_string_literal: true

# Allow RSpec stubs (allow/expect...to receive) and stub_const on Functionable modules.
# Functionable blocks singleton method definitions and const_set, which RSpec uses for stubs.
#
# Monkey-patch Functionable.extended so that any module extending Functionable in test
# gets permissive versions of the hooks that would otherwise block RSpec stubs.
module Functionable
  class << self
    alias_method :original_extended, :extended

    def extended(descendant)
      original_extended(descendant)

      descendant.singleton_class.class_eval <<~PATCH, __FILE__, __LINE__ + 1
        def singleton_method_added(name, allowed: %i[method_added singleton_method_added].freeze)
          return super(name) if allowed.include?(name) || instance_variable_get(:@functionable)
        end

        def remove_method(name)
          return super if instance_variable_get(:@functionable)
          Module.instance_method(:remove_method).bind_call(self, name)
        end

        def const_set(name, value)
          Module.instance_method(:const_set).bind_call(self, name, value)
        end
      PATCH
    end
  end
end
