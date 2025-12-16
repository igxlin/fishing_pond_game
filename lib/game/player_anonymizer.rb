# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require 'securerandom'
require_relative '../types'

# PlayerAnonymizer manages player anonymization to prevent cheating
# Generates random string IDs so participants cannot identify their "partners" by player_name
class PlayerAnonymizer
  extend T::Sig

  sig { void }
  def initialize
    @real_to_anon = T.let({}, T::Hash[String, String])
    @anon_to_real = T.let({}, T::Hash[String, String])
  end

  sig { params(real_name: String).returns(String) }
  def anonymize(real_name)
    # Return existing mapping if available
    return T.must(@real_to_anon[real_name]) if @real_to_anon.key?(real_name)

    # Generate new anonymous ID, format: Player_XXXXXXXX (8 hex chars)
    loop do
      anon_id = "Player_#{generate_random_id}"

      # Ensure ID is unique
      unless @anon_to_real.key?(anon_id)
        @real_to_anon[real_name] = anon_id
        @anon_to_real[anon_id] = real_name
        return anon_id
      end
    end
  end

  sig { params(anon_id: String).returns(T.nilable(String)) }
  def deanonymize(anon_id)
    @anon_to_real[anon_id]
  end

  sig { params(real_names: T::Array[String]).returns(T::Array[String]) }
  def anonymize_all(real_names)
    real_names.map { |name| anonymize(name) }
  end

  sig { params(anon_ids: T::Array[String]).returns(T::Array[String]) }
  def deanonymize_all(anon_ids)
    anon_ids.map { |id| deanonymize(id) || id }
  end

  sig { params(history: T::Hash[String, PlayerHistory]).returns(T::Hash[String, PlayerHistory]) }
  def anonymize_history(history)
    anonymized = {}
    history.each do |real_name, player_history|
      anon_id = anonymize(real_name)

      # Anonymize partner names in history
      anon_partners = player_history.partners.map { |p| p.empty? ? "" : anonymize(p) }

      anonymized[anon_id] = PlayerHistory.new(
        partners: anon_partners,
        catches: player_history.catches,
        scores: player_history.scores
      )
    end
    anonymized
  end

  sig { returns(T::Hash[String, String]) }
  def get_mappings
    # Return copy of mappings for report generation
    @anon_to_real.dup
  end

  private

  sig { returns(String) }
  def generate_random_id
    # Generate 8-character hexadecimal string
    SecureRandom.hex(4)
  end
end
