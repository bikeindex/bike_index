class LookupCode < ActiveRecord::Base
  RESERVED_XYZ_CODES = %w{
    QPQFP
    VFP1FV
    FAQ
    A8QV7
    CQN7AC7
    MAPX1NC
    WHV
    5FAPCH
    PFCFN7
    M1NF
    PFC157FP
    1NQFX
    AQM1N
  }

  before_create :init_xyz_code
  def init_xyz_code
    self.xyz_code = LookupCode.generate_random
  end

  def LookupCode.release_unused_codes
    # Find codes that are in the lookup_codes table, 
    # but NOT in the bikes table. And that were
    # created a while ago.
    LookupCode.joins("LEFT OUTER JOIN bikes on bikes.xyz_code = lookup_codes.xyz_code").
      where("bikes.xyz_code is null").
      where("lookup_codes.created_at < ?", DateTime.now - 6.hours).
      select("lookup_codes.id").each do |r|
        r.destroy
      end
  end

  # 21^3 = 9_261
  # 21^4 = 194_481
  # 21^5 = 4_084_101
  # 21^6 = 85_766_121
  # 21^7 = 1_801_088_541
  # 21^8 = 37_822_859_361
  # 21^9 = 794_280_046_581

  def LookupCode.generate_random
    # four digit:
    # n = Random.rand(194_480 - 9_261) + 9_261
    # five digit:
    # n = Random.rand(4_084_100 - 194_481) + 194_481
    # six digit:
    n = Random.rand(85_766_120 - 4_084_101) + 4_084_101
    LookupCode.n_to_obscode(n)
  end

  def LookupCode.next_code(max_tries=100)    
    begin
      x = LookupCode.create!
      if RESERVED_XYZ_CODES.include? x.xyz_code
        return LookupCode.next_code(max_tries - 1)
      end
      if x.xyz_code =~ /^\d+$/
        # We don't want any all-numeric codes
        return LookupCode.next_code(max_tries - 1)
      end
      if x.xyz_code =~ /VV/
        # don't allow fake Ws
        return LookupCode.next_code(max_tries - 1)
      end    
    rescue ActiveRecord::RecordNotUnique
      if max_tries > 1
        return LookupCode.next_code(max_tries - 1)
      else
        raise
      end
    end
    return x.xyz_code
  end

  def LookupCode.n_to_obscode(n)
    n.to_s(21).tr("0123456789abcdefghijk", "a8cqfh1j7xmnp5vw23469").upcase
  end
    
  def LookupCode.obscode_to_n(c)
    # Once we've generated the code, we probably don't
    # care what the integer value was anymore.
    LookupCode.disambiguate(c).downcase.tr("a8cqfh1j7xmnp5vw23469", "0123456789abcdefghijk").to_i(21)
  end
  
  def LookupCode.disambiguate(c)
    c.downcase.tr("0123456789abcdefghijklmnopqrstuvwxyz", "q123456789a8cqffch1jx1mnqpqp57vvwxv2").upcase
  end
end
