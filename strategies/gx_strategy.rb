# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative '../lib/strategy/base_strategy'

class GxStrategy < BaseStrategy
  extend T::Sig

  sig do
    override.params(
      round_number: Integer,
      turn_number: Integer,
      pond_fish: Integer,
      my_history: T::Array[Integer],
      partner_history: T::Array[Integer],
      partner_name: String,
      all_players_history: T::Hash[String, PlayerHistory]
    ).returns(Integer)
  end
  def choose_catch(
    round_number,
    turn_number,
    pond_fish,
    my_history,
    partner_history,
    partner_name,
    all_players_history
  )
    log_thought("Pond has #{pond_fish} fish")

    # Greedy in the first round, as I do not know what is good.
    return greedy(pond_fish) if round_number <= 1

    # If the partner is greedy, it is not good to be humble.
    return greedy(pond_fish) if partner_history.last == 30

    best = the_best_catches(all_players_history, [])
    catches = best[:catches]

    unless catches.nil? || turn_number - 1 >= catches.length
      num = catches[turn_number - 1] + 1
      return [num, 30].min
    end

    greedy(pond_fish)
  end

  sig do
    override.params(
      round_number: Integer,
      all_players: T::Array[String],
      all_players_history: T::Hash[String, PlayerHistory]
    ).returns([String, String])
  end
  def choose_partners(round_number, all_players, all_players_history)
    log_thought("Choosing stable partners")

    # Randomly pick if it is the first round.
    if round_number <= 1
      samples = all_players.sample(2)
      return ['', ''] if samples.nil?

      [samples[0], samples[1]]
    end

    # Find the best player.
    # If they are greedy, I, simulating their strategies, will be
    # greedy. If they have better idea, I, simulating their strategies,
    # will have great cooperation.
    best_catches = the_best_catches(all_players_history, [])
    second_best_catches = the_best_catches(all_players_history, [best_catches[:player_name]])

    [best_catches[:player_name], second_best_catches[:player_name]]
  end

  private

  sig do
    params(
      pond_fish: Integer
    ).returns(Integer)
  end
  def greedy(pond_fish)
    [30, [(pond_fish - 30), 1].max].min
  end

  sig do
    params(
      all_players_history: T::Hash[String, PlayerHistory],
      players_excluded: T::Array[String]
    ).returns({ player_name: String, catches: T::Array[Integer] })
  end
  def the_best_catches(all_players_history, players_excluded)
    catches = T.let([], T::Array[Integer])
    best_score = 0
    player_name = ''

    all_players_history.each do |pname, player_history|
      player_history.catches.each do |arr|
        next if players_excluded.include?(pname)

        score = arr.sum
        next if score <= best_score

        catches = arr
        best_score = score
        player_name = pname
      end
    end

    {
      player_name: player_name,
      catches: catches
    }
  end
end
