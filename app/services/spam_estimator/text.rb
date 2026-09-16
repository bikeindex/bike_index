module SpamEstimator
  module Text
    extend Functionable

    MALICIOUS_REGEX = /
      <\s*(?:script|iframe|object|embed)[\s>\/] |
      javascript\s*: |
      <[^>]*\son\w+\s*= |
      \bunion\s+select\b |
      \b(?:drop|truncate)\s+table\b |
      \b(?:delete\s+from|insert\s+into)\b |
      ['"]\s*or\s+['"]?\d+['"]?\s*=\s*['"]?\d+ |
      \bpg_sleep\s*\( |
      \bsleep\s*\(\s*\d |
      \bwaitfor\s+delay\b |
      \bdbms_pipe\.receive_message\b |
      \bxor\s*\( |
      \bselect\b[^;]*\bfrom\s+dual\b |
      \bsysdate\s*\( |
      ;\s*(?:drop|delete|truncate|exec)\b
    /xi

    # Scored by estimate, so these are only terms that never show up in a real registration or
    # theft report — Soma, Norco and Ultram count only after a buying verb
    PHARMACY_REGEX = /\b(?:
        erectile\s+dysfunction | (?:buy|order|purchase)\s+(?:soma|norco|ultram) |
        pain\s?o\s?soma | viagra | cialis | levitra | kamagra | sildenafil | tadalafil | vardenafil | avanafil |
        cenforce | vidalista | fildena | tramadol | tapentadol | aspadol | oxycodone | oxycontin | roxicodone | hydrocodone | percocet |
        vicodin | lorcet | lortab | codeine | fentanyl | dilaudid | hydromorphone | suboxone | subutex | buprenorphine |
        methadone | demerol | meperidine | opana | darvocet | darvon | xanax | alprazolam | farmapram | ksalol | valium |
        diazepam | klonopin | clonazepam | rivotril | lorazepam | ativan | adderall | ritalin | concerta | methylphenidate |
        vyvanse | provigil | modafinil | modalert | modvigil | armodafinil | artvigil | waklert | ambien | zolpidem |
        belbien | belbein | zopiclone | eszopiclone | restoril | carisoprodol | fioricet | butalbital | pregabalin |
        gabapentin | phentermine | adipex | meridia | sibutramine | reductil | ozempic | semaglutide | cytotec | misoprostol
      )\b/xi

    # crypto, gambling, adult, gift-card and pharmacy terms that SEO-spam profiles exist to promote.
    # Word boundaries matter: usernames are auto-generated random strings, so
    # unanchored substrings ("Judith", "Hagen", "Sloth", "Donohue") would ban real people.
    SEO_SPAM_REGEX = /(?:
      \b(?:
        bitcoin | btc | ethereum | crypto(?:currency|\s?wallet)? | blockchain | binance |
        coinbase | dogecoin | altcoin | memecoin | defi | web3 | metamask | airdrop |
        presale | usdt | tether |
        casino | kasino | gambling | roulette | blackjack | baccarat | poker | sportsbook |
        jackpot | judi | togel | toto | situs | gacor | bandar | slot | agen | maxwin |
        terpercaya | taruhan | alternatif | gampang | pragmatic\s+play | scatter\s+hitam |
        rtp | bet365 | betting | wager |
        bokep | hentai | xvideo | (?:phim|clip|truyen)\s?sex |
        nha\s+cai | ca\s+cuoc | da\s+ga | soi\s+keo | no\s+hu | xoc\s+dia |
        nap\s+tien | dang\s+nhap | truc\s+tuyen | khuyen\s+mai | uy\s+tin |
        game\s+bai | co\s+bac | song\s+bac | xo\s+so | lo\s+de |
        link\s+truy\s+cap | clip\s+(?:hot|nong) |
        # estimate scores PHARMACY_REGEX against frame models and theft reports, so anything that
        # shows up in a real one ("Omega Pharma", "stolen outside the pharmacy") stays here
        pharmacy | pharmacies | pharmacists? | pharma | drugstore | prescriptions? | medications? |
        medicines? | meds | painkillers? | opioids? | impotence |
        # "MG Road" is a common street name in India
        \d+\s?mg(?!\s+r(?:oa)?d\b)
      )\b | 18\+ |
      # spam usernames run it into digits (pills4cure), so a word boundary won't match
      (?<![a-z])pills?(?![a-z]) |
      # Gift-card "check your balance" farms run the brand together in usernames and
      # domains (mcgiftgiftcardmall3, vanillaprepaid.io), so these can't be \b-anchored.
      gift\s?(?:cards?|code) | prepaid |
      (?:mc|my|wm|walmart|five\s?back|vanilla|visa|amex|master(?:card)?)-?\s?e?-?gift |
      (?:one|my)-?\s?vanilla | vanilla-?\s?balance | secure-?\s?spend |
      (?:card|gift)\s?balance | balance\s?(?:check|inquiry|inquiries) |
      check\s?(?:my|your|the)?\s?balance | reward\s?cards? |
      card\s?activation | activate\s+(?:my\s|your\s|the\s)?(?:gift\s?)?card |
      redeem\s+(?:code|card) |
      #{PHARMACY_REGEX}
    )/xi

    def looks_malicious?(str)
      return false if str.blank?

      str.match?(MALICIOUS_REGEX)
    end

    # matched terms and their counts, recorded on the ban so false positives are auditable.
    # Vietnamese spam appears both with and without diacritics, so strip them first —
    # I18n.transliterate can't (it renders Vietnamese vowels as "?")
    def seo_spam_matches(str)
      return {} if str.blank?

      strip_diacritics(str).scan(SEO_SPAM_REGEX).map { |term| term.downcase.gsub(/\s+/, " ") }.tally
    end

    # eariot are the most frequent letters - this could be incorporated into calculations
    # Currently, doing a weird vowel count thing
    def estimate(str)
      return 0 if str.blank?
      return 100 if looks_malicious?(str)

      str_length ||= str.length.to_f
      return 10 if str_length == 1
      # pharmacy spam is well-formed prose, so the shape checks below score it 0
      return 100 if PHARMACY_REGEX.match?(str)

      str_downlate ||= downcase_transliterate(str)

      total = vowel_frequency_suspiciousness(str, str_length, str_downlate) +
        space_count_suspiciousness(str, str_length, str_downlate) +
        capital_count_suspiciousness(str, str_length, str_downlate) +
        non_letter_count_suspiciousness(str, str_length, str_downlate)

      total.clamp(0, 100)
    end

    #
    # private below here
    #

    def strip_diacritics(str)
      str.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("đĐ", "dD")
    end

    def vowel_frequency_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 4 # 3 letters or less get a pass

      vowel_percent = vowel_ratio(str, str_length) * 100
      # In testing vowel percentage, 20-60% is reasonable for short strings
      # longer strings should be below 40%
      susness = if str_length < 6
        [0, 100].include?(vowel_percent) ? 40 : 0
      elsif vowel_percent < 5
        (str_length < 11) ? 80 : 100
      elsif vowel_percent < 20
        offset = (vowel_percent > 12) ? 90 : 120
        if str_length < 9
          offset -= 50
        elsif str_length < 14
          offset -= 20
        elsif str_length < 30
          offset -= 10
        end
        offset - vowel_percent
      elsif vowel_percent > 69
        if str_length < 15
          vowel_percent
        elsif str_length < 30
          vowel_percent + 15
        else
          100
        end
      elsif vowel_percent > 40
        vowel_percent - 40
      else
        0
      end
      susness.clamp(0, 100)
    end

    def vowel_ratio(str, str_length = nil, str_downlate = nil)
      str_downlate ||= downcase_transliterate(str)

      only_letters_and_spaces = str_downlate.gsub(/[^a-z|\s]/, "")

      only_letters_and_spaces.count("aeiouy") / only_letters_and_spaces.length.to_f
    end

    def capital_count_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 7

      capital_ratio = (str.count("ABCDEFGHIJKLMNOPQRSTUVWXYZ") / str_length) * 100
      susness = if str_length < 16
        capital_ratio - 50
      elsif str_length < 25
        capital_ratio - 40
      else
        capital_ratio - 10
      end
      # People love capitalizing things on the internet :/
      0.3 * susness.clamp(0, 100)
    end

    def non_letter_count_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 7

      str_downlate ||= downcase_transliterate(str)
      non_letter_count = (1 - (str_downlate.count("abcdefghijklmnopqrstuvwxyz ") / str_length)) * 100

      susness = if str_length < 16
        non_letter_count - 50
      elsif str_length < 25
        non_letter_count - 40
      else
        non_letter_count - 10
      end
      susness.clamp(0, 100)
    end

    def space_count_suspiciousness(str, str_length = nil, str_downlate = nil)
      str_length ||= str.length.to_f
      return 0 if str_length < 12

      spaces_count = str.count(" -")
      if str_length < 20
        return (spaces_count < 1) ? 10 : 0
      end

      target_space_count = (str_length / 12).floor
      return 0 if spaces_count >= target_space_count

      multiplier = (str_length < 31) ? 40 : 60
      susness = (target_space_count - spaces_count) * multiplier

      susness.clamp(0, 100)
    end

    def downcase_transliterate(str)
      I18n.transliterate(str).downcase
    end

    conceal :strip_diacritics, :vowel_frequency_suspiciousness, :vowel_ratio,
      :capital_count_suspiciousness, :non_letter_count_suspiciousness,
      :space_count_suspiciousness, :downcase_transliterate
  end
end
