module EmailNormalizer
  extend Functionable

  def normalize(email = nil)
    Binxtils::InputNormalizer.string(email)&.downcase
  end

  def obfuscate(email = nil)
    return nil unless email.present?

    email.sub(/\A(..?)(.*)?@(.)(.*)(..)\z/) {
      $1 + "*" * $2.length + "@" + $3 + "*" * $4.length + $5
    }
  end
end
