module Phonifyerable
  extend ActiveSupport::Concern

  def phone_display
    Phonifyer.display(phone)
  end
end
