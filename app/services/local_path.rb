# frozen_string_literal: true

# Whether a return_to is a path of our own, so a link can't send someone off-site
module LocalPath
  extend Functionable

  # "//host" is off-site despite the leading slash. Browsers read a backslash as a slash
  # and drop tabs and newlines, so "/\evil.com" and "/\t/evil.com" are too
  def only(target)
    target if target.to_s.match?(%r{\A/(?!/)[^\\[:space:][:cntrl:]]*\z})
  end
end
