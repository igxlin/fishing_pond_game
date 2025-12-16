# typed: false
# frozen_string_literal: true

require_relative '../../lib/game/pond'
require_relative '../../lib/types'

RSpec.describe Pond do
  let(:config) { GameConfig.new(min_growth_rate: 1.2, max_growth_rate: 1.2) }  # Fixed growth rate for deterministic tests
  let(:pond) { Pond.new(config) }

  describe '#initialize' do
    it 'starts with 100 fish' do
      expect(pond.fish).to eq(100)
    end

    it 'is not depleted initially' do
      expect(pond.depleted?).to be false
    end
  end

  describe '#execute_turn' do
    context 'when total catch is within pond capacity' do
      it 'allows both players to catch fish' do
        result = pond.execute_turn(10, 15)

        expect(result.player1_catch).to eq(10)
        expect(result.player2_catch).to eq(15)
        expect(result.success).to be true
      end

      it 'removes caught fish from pond and grows remaining' do
        result = pond.execute_turn(10, 15)
        # 100 - 25 = 75, then 75 * 1.2 = 90
        expect(result.pond_fish_after).to eq(90)
        expect(pond.fish).to eq(90)
      end

      it 'grows remaining fish by 20%' do
        result = pond.execute_turn(10, 10)
        # 100 - 20 = 80, then 80 * 1.2 = 96
        expect(result.pond_fish_after).to eq(96)
        expect(pond.fish).to eq(96)
      end
    end

    context 'when total catch exceeds pond capacity' do
      it 'returns failure' do
        # Catches are capped at 30 each, so 30 + 30 = 60 < 100
        # Need to make pond smaller first
        pond.execute_turn(20, 20) # 100 - 40 = 60, * 1.2 = 72
        pond.execute_turn(20, 20) # 72 - 40 = 32, * 1.2 = 38
        result = pond.execute_turn(30, 30) # 38 < 60, so this will fail

        expect(result.success).to be false
      end

      it 'depletes the pond to 0' do
        pond.execute_turn(20, 20) # 100 - 40 = 60, * 1.2 = 72
        pond.execute_turn(20, 20) # 72 - 40 = 32, * 1.2 = 38
        pond.execute_turn(30, 30) # 38 < 60, overfishing

        expect(pond.fish).to eq(0)
        expect(pond.depleted?).to be true
      end

      it 'attempts to catch more than available (capped at 30 each)' do
        pond.execute_turn(20, 20) # 100 - 40 = 60, * 1.2 = 72
        pond.execute_turn(20, 20) # 72 - 40 = 32, * 1.2 = 38
        result = pond.execute_turn(60, 60) # Capped to 30, 30

        # Catches are capped at 30
        expect(result.player1_catch).to eq(30)
        expect(result.player2_catch).to eq(30)
        expect(result.success).to be false
        expect(result.pond_fish_after).to eq(0)
      end
    end

    context 'when catches are at exact pond limit' do
      it 'succeeds when catch equals pond fish' do
        # Request 30 and 30 (capped values), but pond only has 60
        pond.execute_turn(20, 20) # 100 - 40 = 60, * 1.2 = 72
        result = pond.execute_turn(36, 36) # Will be capped to 30, 30. 72 - 60 = 12, * 1.2 = 14

        expect(result.success).to be true
        expect(pond.fish).to eq(14)
      end
    end

    context 'input sanitization' do
      it 'caps catches at max_catch_per_turn (30)' do
        result = pond.execute_turn(50, 40)

        expect(result.player1_catch).to eq(30)
        expect(result.player2_catch).to eq(30)
      end

      it 'treats negative catches as 0' do
        result = pond.execute_turn(-5, -10)

        expect(result.player1_catch).to eq(0)
        expect(result.player2_catch).to eq(0)
      end
    end
  end
end
