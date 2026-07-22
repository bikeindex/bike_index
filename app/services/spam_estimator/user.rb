module SpamEstimator
  module User
    extend Functionable

    MARK_SPAM_PERCENT = 90 # May modify in the future!

    # crypto, gambling and adult terms that SEO-spam profiles exist to promote.
    # Indonesian and Vietnamese carry most of the volume — see the multi-word
    # section below for why those require a literal space.
    SEO_SPAM_REGEX = /(?:
      \b(?:
        bitcoin | btc | ethereum | crypto(?:currency|\s?wallet)? | blockchain | binance |
        coinbase | dogecoin | altcoin | memecoin | defi | web3 | metamask | airdrop |
        presale | usdt | tether |
        casino | kasino | gambling | roulette | blackjack | baccarat | poker | sportsbook |
        jackpot | judi | togel | toto | situs | gacor | bandar | slot | agen | maxwin |
        terpercaya | taruhan | alternatif | pragmatic | gampang | scatter | rtp |
        bet365 | betting | wager |
        bokep | hentai | xvideo | (?:phim|clip|truyen|truyện)\s?sex
      )\b |
      # Word boundaries are load-bearing above: usernames are auto-generated 22-char
      # random strings, so substring matches ("Judith", "Hagen", "Sloth", "Donohue")
      # would ban real people. These phrases require a space for the same reason.
      nh[àa]\s+c[áa]i | c[áa]\s+c[uư][ợo]c | đ[áa]\s+g[àa] | soi\s+k[èe]o |
      n[ổo]\s+h[ũu] | x[óo]c\s+đ[ĩi]a | n[ạa]p\s+ti[ềe]n | đ[ăa]ng\s+nh[ậa]p |
      tr[ựu]c\s+tuy[ếe]n | khuy[ếe]n\s+m[ãa]i | uy\s+t[íi]n |
      game\s+b[àa]i | c[ờo]\s+b[ạa]c | s[òo]ng\s+b[ạa]c | x[ổo]\s+s[ốo] | l[ôo]\s+đ[ềe] |
      link\s+truy\s+c[ậa]p | clip\s+(?:hot|n[óo]ng) | 18\+
    )/xi

    def estimate(user)
      return 0 if user.blank?

      # each crypto/gambling reference is a strong signal, stacked onto the text score
      score = spammy_text_estimate(user) + 30 * seo_spam_reference_count(user)

      (score - bike_ownership_reduction(user)).clamp(0, 100)
    end

    #
    # private below here
    #

    # count of references anywhere in the public profile, including link URLs and handles
    def seo_spam_reference_count(user)
      scannable_strings(user).join(" ").scan(SEO_SPAM_REGEX).count
    end

    # description and title are the SEO-spam payload; weight them far above name/username
    # (URLs/handles are only regex-scanned above — the estimator scores them as gibberish)
    def spammy_text_estimate(user)
      heavy = Text.estimate([user.description, user.title].select(&:present?).join(" "))
      light = Text.estimate([user.name, user.username].select(&:present?).join(" "))

      heavy + 0.2 * light
    end

    def scannable_strings(user)
      [user.name, user.title, user.description, user.username, user.mb_link_title,
        user.mb_link_target, user.twitter, user.instagram].select(&:present?)
    end

    # real registrations are strong evidence against spam
    def bike_ownership_reduction(user)
      case user.bikes.limit(2).count
      when 0 then 0
      when 1 then 30
      else 50
      end
    end

    conceal :seo_spam_reference_count, :spammy_text_estimate, :scannable_strings, :bike_ownership_reduction
  end
end
