# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../types'

class Pond
  extend T::Sig

  sig { params(config: GameConfig).void }
  def initialize(config = GameConfig.new)
    @config = T.let(config, GameConfig)
    @fish = T.let(config.initial_fish, Integer)
    @depleted = T.let(false, T::Boolean)
  end

  sig { returns(Integer) }
  attr_reader :fish

  sig { returns(T::Boolean) }
  def depleted?
    @depleted
  end

  sig { params(player1_catch: Integer, player2_catch: Integer).returns(TurnResult) }
  def execute_turn(player1_catch, player2_catch)
    # Sanitize inputs
    p1_catch = [0, [player1_catch, @config.max_catch_per_turn].min].max
    p2_catch = [0, [player2_catch, @config.max_catch_per_turn].min].max

    pond_before = @fish
    total_catch = p1_catch + p2_catch

    if total_catch <= @fish
      # Success: both get their catch
      @fish -= total_catch

      # Fish reproduce with random growth rate between min and max
      actual_growth_rate = random_growth_rate
      @fish = (@fish * actual_growth_rate).floor

      TurnResult.new(
        pond_fish_before: pond_before,
        player1_catch: p1_catch,
        player2_catch: p2_catch,
        success: true,
        pond_fish_after: @fish,
        growth_rate_applied: actual_growth_rate
      )
    else
      # Overfishing: both get 0, pond depletes
      @fish = 0
      @depleted = true

      TurnResult.new(
        pond_fish_before: pond_before,
        player1_catch: p1_catch,
        player2_catch: p2_catch,
        success: false,
        pond_fish_after: 0,
        growth_rate_applied: 0.0
      )
    end
  end

  private

  sig { returns(Float) }
  def random_growth_rate
    # Generate random growth rate between min and max
    min = @config.min_growth_rate
    max = @config.max_growth_rate
    min + rand * (max - min)
  end
end
