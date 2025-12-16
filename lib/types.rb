# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

# Player's historical data across all rounds
class PlayerHistory < T::Struct
  const :partners, T::Array[String]              # Partners in each round
  const :catches, T::Array[T::Array[Integer]]    # Catches per round [[5,6,4,...], ...]
  const :scores, T::Array[Integer]               # Total score per round
end

# Configuration for the game
class GameConfig < T::Struct
  const :initial_fish, Integer, default: 100
  const :growth_rate, Float, default: 1.2  # Deprecated: use min/max_growth_rate instead
  const :min_growth_rate, Float, default: 1.15
  const :max_growth_rate, Float, default: 1.25
  const :max_catch_per_turn, Integer, default: 30
  const :turns_per_pairing, Integer, default: 10
end

# Result of a single turn
class TurnResult < T::Struct
  const :pond_fish_before, Integer
  const :player1_catch, Integer
  const :player2_catch, Integer
  const :success, T::Boolean
  const :pond_fish_after, Integer
  const :growth_rate_applied, Float, default: 0.0  # Actual growth rate used this turn
end

# Pairing of two players
class Pairing < T::Struct
  const :player1_name, String
  const :player2_name, String
  const :was_mutual_first_choice, T::Boolean, default: false
end
