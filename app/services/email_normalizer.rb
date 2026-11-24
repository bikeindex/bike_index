module EmailNormalizer
  extend Functionable

  GMAIL_DOMAINS = %w[gmail.com googlemail.com].freeze

  def normalize(email = nil)
    Binxtils::InputNormalizer.string(email)&.downcase
  end

  # The inbox an address delivers to, for comparing addresses rather than storing them: a +tag is dropped, and
  # Gmail ignores dots and treats googlemail.com as gmail.com
  def mailbox(email = nil)
    local, domain = normalize(email)&.split("@", 2)
    return nil if domain.blank?

    local = local.sub(/\+.*/, "")
    if GMAIL_DOMAINS.include?(domain)
      local = local.delete(".")
      domain = GMAIL_DOMAINS.first
    end
    "#{local}@#{domain}"
  end

  def obfuscate(email = nil)
    return nil unless email.present?

    email.sub(/\A(..?)(.*)?@(.)(.*)(..)\z/) {
      $1 + "*" * $2.length + "@" + $3 + "*" * $4.length + $5
    }
  end
end
