require 'rails_helper'

# Tests to define what this custom matcher should do
# file is spec/lib because if it was in support it would be required by rails_helper.rb
RSpec.describe 'custom match_hash_flexibly and RspecHashMatcher' do # rubocop:disable RSpec/DescribeClass
  context 'with two hashes' do
    describe 'match_hash_flexibly' do
      let(:time) { Time.current }
      let(:hash_1) { { something: 12, 'else' => 'party', time: } }
      let(:hash_2) { { 'something' => '12', else: :party, time: time + 0.1 } }

      it 'matches indifferently' do
        expect(RspecHashMatcher.recursive_match_hashes(hash_1, hash_2)).to eq([])
        expect(hash_1).to match_hash_flexibly hash_2
      end

      context 'with hash_2 missing key' do
        let(:hash_2) { hash_1.except(:something) }
        let(:target_error) do
          [
            { key: 'keys', value: %w[else time], match_value: %w[else something time],
              match_with: 'equal' }
          ]
        end

        it "doesn't match" do
          expect(RspecHashMatcher.recursive_match_hashes(hash_1, hash_2)).to eq(target_error)
          expect(hash_1).not_to match_hash_flexibly hash_2
        end
      end

      context 'with hash_1 missing key' do
        let(:hash_1) { hash_2.except(:else) }

        it "doesn't match" do
          expect(hash_1).not_to match_hash_flexibly hash_2
        end
      end

      context 'with nested hash' do
        let(:hash_1) { { something: { foo: 'bar', bar: :foo } } }
        let(:hash_2) { { 'something' => { bar: :foo, foo: :bar } }.as_json }

        it 'matches' do
          expect(hash_1).to match_hash_flexibly hash_2
        end

        context 'with a non match' do
          let(:hash_2) { { 'something' => { bar: :foo, foo: :bar, barfoo: :foobar } } }

          it "doesn't match" do
            expect(hash_1).not_to match_hash_flexibly hash_2
          end
        end
      end
    end
  end

  context 'with ActiveRecord model' do
    let(:time) { 1.hour.ago }
    let(:nonprofit) do
      Nonprofit.new(revenue_total: 200.10, name: 'nonprofit', applied_at: time + 0.5)
    end
    let(:hash_1) { { revenue_total: '200.1', name: 'nonprofit', applied_at: time } }

    it 'matches' do
      expect(RspecHashMatcher.send(:times_match?, nonprofit.applied_at,
                                   hash_1[:applied_at])).to be_truthy
      expect(nonprofit).to match_hash_flexibly(hash_1)
    end

    context 'with non-matching' do
      let(:hash_2) { hash_1.merge(applied_at: time + 3) }

      it 'does not matches' do
        expect(nonprofit).not_to match_hash_flexibly(hash_2)
      end
    end
  end

  describe 'times_match?' do
    let(:time_1) { Time.at(1_718_123_393) } # 2024-06-11 16:29:53
    let(:time_2) { time_1 - 0.2 }
    let(:round_time_1) { RspecHashMatcher.send(:round_time, time_1) }
    let(:round_time_2) { RspecHashMatcher.send(:round_time, time_2) }

    it 'matches the time' do
      expect(RspecHashMatcher.send(:times_match?, time_1, time_2)).to be_truthy
    end

    context 'with 1 second later' do
      let(:time_2) { time_1 + 1 }

      it 'matches the time' do
        expect(RspecHashMatcher.send(:times_match?, time_1, time_2)).to be_truthy
      end
    end

    context 'with 1 minute later' do
      let(:time_2) { time_1 + 1.minute }

      it 'is falsey' do
        expect(RspecHashMatcher.send(:times_match?, time_1, time_2)).to be_falsey
      end

      context 'with match_time_within 10.minutes' do
        it 'is truthy' do
          result = RspecHashMatcher.send(:times_match?, time_1, time_2,
                                         match_time_within: 10.minutes)
          expect(result).to be_truthy
        end
      end
    end
  end
end
