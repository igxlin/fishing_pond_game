# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'types'
require_relative 'game/round'
require_relative 'game/tournament'
require_relative 'game/player_anonymizer'
require_relative 'strategy/base_strategy'

class ReportGenerator
  extend T::Sig

  sig { params(round_result: RoundResult, all_players_history: T::Hash[String, PlayerHistory], output_path: String, strategies: T.nilable(T::Hash[String, BaseStrategy]), anonymizer: T.nilable(PlayerAnonymizer)).void }
  def self.generate_round_report(round_result, all_players_history, output_path, strategies = nil, anonymizer = nil)
    html = build_html(round_result, all_players_history, strategies, anonymizer)
    File.write(output_path, html)
  end

  sig { params(round_result: RoundResult, all_players_history: T::Hash[String, PlayerHistory], strategies: T.nilable(T::Hash[String, BaseStrategy]), anonymizer: T.nilable(PlayerAnonymizer)).returns(String) }
  private_class_method def self.build_html(round_result, all_players_history, strategies, anonymizer)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Round #{round_result.round_number} Report - Fishing Pond Game</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
          }
          h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
          h2 { color: #34495e; margin-top: 30px; }
          h3 { color: #7f8c8d; }
          .pairing {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .pairing-header {
            font-size: 1.2em;
            font-weight: bold;
            margin-bottom: 15px;
            color: #2980b9;
          }
          .mutual-choice {
            background-color: #d5f4e6;
            border-left: 4px solid #27ae60;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
          }
          th {
            background-color: #34495e;
            color: white;
            padding: 12px;
            text-align: left;
          }
          td {
            padding: 10px 12px;
            border-bottom: 1px solid #ecf0f1;
          }
          tr:hover {
            background-color: #f8f9fa;
          }
          .success {
            background-color: #d5f4e6;
          }
          .overfishing {
            background-color: #fadbd8;
            font-weight: bold;
          }
          .leaderboard {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .rank-1 { color: #f39c12; font-weight: bold; }
          .rank-2 { color: #95a5a6; font-weight: bold; }
          .rank-3 { color: #cd7f32; font-weight: bold; }
          .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
          }
          .stat-card {
            background: white;
            padding: 15px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .stat-label {
            color: #7f8c8d;
            font-size: 0.9em;
          }
          .stat-value {
            font-size: 1.8em;
            font-weight: bold;
            color: #2c3e50;
          }
          .thoughts {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            overflow-x: auto;
          }
          .thoughts table {
            width: 100%;
            font-size: 0.9em;
          }
          .thoughts td {
            padding: 8px 12px;
            vertical-align: top;
            border: 1px solid #e0e0e0;
            max-width: 300px;
            word-wrap: break-word;
          }
          .thoughts th {
            position: sticky;
            top: 0;
            z-index: 10;
          }
        </style>
      </head>
      <body>
        <h1>🎣 Round #{round_result.round_number} Report</h1>

        <h2>📊 Round Summary</h2>
        <div class="stats">
          <div class="stat-card">
            <div class="stat-label">Total Pairings</div>
            <div class="stat-value">#{round_result.pairings.length}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">Mutual First Choices</div>
            <div class="stat-value">#{round_result.pairings.count(&:was_mutual_first_choice)}</div>
          </div>
        </div>

        <h2>🤝 Pairings</h2>
        #{generate_pairings_section(round_result, anonymizer)}

        <h2>🏆 Leaderboard After Round #{round_result.round_number}</h2>
        #{generate_leaderboard(all_players_history, anonymizer)}

        <h2>📈 Strategy Insights</h2>
        #{generate_insights(round_result, all_players_history, anonymizer)}

        #{strategies ? "<h2>💭 Strategy Thoughts</h2>\n        #{generate_thoughts_section(round_result.round_number, strategies, anonymizer)}" : ""}

      </body>
      </html>
    HTML
  end

  sig { params(round_result: RoundResult, anonymizer: T.nilable(PlayerAnonymizer)).returns(String) }
  private_class_method def self.generate_pairings_section(round_result, anonymizer)
    round_result.pairing_results.map do |_key, pairing_result|
      mutual_class = round_result.pairings.any? do |p|
        (p.player1_name == pairing_result.player1_name || p.player2_name == pairing_result.player1_name) &&
        p.was_mutual_first_choice
      end ? "pairing mutual-choice" : "pairing"

      # Display real names in report
      p1_name = anonymizer ? (anonymizer.deanonymize(pairing_result.player1_name) || pairing_result.player1_name) : pairing_result.player1_name
      p2_name = anonymizer ? (anonymizer.deanonymize(pairing_result.player2_name) || pairing_result.player2_name) : pairing_result.player2_name

      <<~HTML
        <div class="#{mutual_class}">
          <div class="pairing-header">
            #{p1_name} vs #{p2_name}
            #{mutual_class.include?('mutual') ? '💚 (Mutual First Choice)' : ''}
          </div>
          <table>
            <thead>
              <tr>
                <th>Turn</th>
                <th>Pond Fish</th>
                <th>#{p1_name} Catch</th>
                <th>#{p2_name} Catch</th>
                <th>Result</th>
                <th>Pond After</th>
              </tr>
            </thead>
            <tbody>
              #{generate_turn_rows(pairing_result)}
            </tbody>
          </table>
          <div style="margin-top: 15px; font-weight: bold;">
            Final Scores: #{p1_name}: #{pairing_result.player1_total} |
            #{p2_name}: #{pairing_result.player2_total}
          </div>
        </div>
      HTML
    end.join("\n")
  end

  sig { params(pairing_result: PairingResult).returns(String) }
  private_class_method def self.generate_turn_rows(pairing_result)
    pairing_result.turn_results.map.with_index do |turn_result, idx|
      turn_number = idx + 1
      row_class = turn_result.success ? "success" : "overfishing"
      result_text = turn_result.success ? "✅ Success" : "❌ Overfishing"

      <<~HTML
        <tr class="#{row_class}">
          <td>#{turn_number}</td>
          <td>#{turn_result.pond_fish_before}</td>
          <td>#{turn_result.player1_catch}</td>
          <td>#{turn_result.player2_catch}</td>
          <td>#{result_text}</td>
          <td>#{turn_result.pond_fish_after}</td>
        </tr>
      HTML
    end.join("\n")
  end

  sig { params(all_players_history: T::Hash[String, PlayerHistory], anonymizer: T.nilable(PlayerAnonymizer)).returns(String) }
  private_class_method def self.generate_leaderboard(all_players_history, anonymizer)
    scores = all_players_history.map do |name, history|
      [name, history.scores.sum]
    end.sort_by { |_name, score| -score }

    rows = scores.map.with_index do |(name, total_score), idx|
      rank = idx + 1
      rank_class = "rank-#{rank}" if rank <= 3
      medal = case rank
              when 1 then "🥇"
              when 2 then "🥈"
              when 3 then "🥉"
              else "#{rank}."
              end

      # Display real name in report
      display_name = anonymizer ? (anonymizer.deanonymize(name) || name) : name

      <<~HTML
        <tr class="#{rank_class}">
          <td>#{medal}</td>
          <td>#{display_name}</td>
          <td>#{total_score}</td>
        </tr>
      HTML
    end.join("\n")

    <<~HTML
      <div class="leaderboard">
        <table>
          <thead>
            <tr>
              <th>Rank</th>
              <th>Player</th>
              <th>Total Score</th>
            </tr>
          </thead>
          <tbody>
            #{rows}
          </tbody>
        </table>
      </div>
    HTML
  end

  sig { params(round_result: RoundResult, all_players_history: T::Hash[String, PlayerHistory], anonymizer: T.nilable(PlayerAnonymizer)).returns(String) }
  private_class_method def self.generate_insights(round_result, all_players_history, anonymizer)
    # Calculate cooperation rate (successful turns / total turns)
    total_turns = round_result.pairing_results.values.sum { |pr| pr.turn_results.length }
    successful_turns = round_result.pairing_results.values.sum { |pr| pr.turn_results.count(&:success) }
    cooperation_rate = total_turns > 0 ? (successful_turns.to_f / total_turns * 100).round(1) : 0.0

    # Calculate pond depletion rate
    depleted_ponds = round_result.pairing_results.values.count do |pr|
      pr.turn_results.any? { |tr| !tr.success }
    end
    depletion_rate = round_result.pairing_results.length > 0 ?
      (depleted_ponds.to_f / round_result.pairing_results.length * 100).round(1) : 0.0

    # Find most/least greedy players
    avg_catches = all_players_history.map do |name, history|
      catches = history.catches.flatten
      avg = catches.empty? ? 0.0 : catches.sum.to_f / catches.length
      [name, avg.round(2)]
    end.sort_by { |_name, avg| -avg }

    most_greedy = avg_catches.first
    most_conservative = avg_catches.last

    # Display real names
    most_greedy_name = most_greedy ? (anonymizer ? (anonymizer.deanonymize(most_greedy[0]) || most_greedy[0]) : most_greedy[0]) : 'N/A'
    most_conservative_name = most_conservative ? (anonymizer ? (anonymizer.deanonymize(most_conservative[0]) || most_conservative[0]) : most_conservative[0]) : 'N/A'

    <<~HTML
      <div class="stats">
        <div class="stat-card">
          <div class="stat-label">Cooperation Rate</div>
          <div class="stat-value">#{cooperation_rate}%</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Pond Depletion Rate</div>
          <div class="stat-value">#{depletion_rate}%</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Most Greedy</div>
          <div class="stat-value" style="font-size: 1.2em;">#{most_greedy_name} (#{most_greedy ? most_greedy[1] : 0})</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Most Conservative</div>
          <div class="stat-value" style="font-size: 1.2em;">#{most_conservative_name} (#{most_conservative ? most_conservative[1] : 0})</div>
        </div>
      </div>
    HTML
  end

  sig { params(round_number: Integer, strategies: T::Hash[String, BaseStrategy], anonymizer: T.nilable(PlayerAnonymizer)).returns(String) }
  private_class_method def self.generate_thoughts_section(round_number, strategies, anonymizer)
    # Get player names and deanonymize for display
    player_anon_ids = strategies.keys.sort
    player_display_names = player_anon_ids.map do |anon_id|
      anonymizer ? (anonymizer.deanonymize(anon_id) || anon_id) : anon_id
    end

    # Organize thoughts by phase and turn: { phase => { turn => { display_name => [messages] } } }
    organized_thoughts = {}

    # Create mapping from anon_id to display name
    id_to_display = {}
    player_anon_ids.each_with_index do |anon_id, idx|
      id_to_display[anon_id] = player_display_names[idx]
    end

    strategies.each do |anon_id, strategy|
      thoughts = strategy.all_thoughts[round_number]
      next if thoughts.nil? || thoughts.empty?

      display_name = id_to_display[anon_id] || anon_id

      thoughts.each do |phase, content|
        organized_thoughts[phase] ||= {}

        if phase == "choose_catch" && content.is_a?(Hash)
          # Turn-by-turn thoughts
          content.each do |turn, messages|
            organized_thoughts[phase][turn] ||= {}
            organized_thoughts[phase][turn][display_name] = messages
          end
        elsif content.is_a?(Array)
          # Phase thoughts (choose_partners)
          organized_thoughts[phase][nil] ||= {}
          organized_thoughts[phase][nil][display_name] = content
        end
      end
    end

    # Generate table rows
    rows = []

    # First, choose_partners phase
    if organized_thoughts["choose_partners"]
      organized_thoughts["choose_partners"].each do |_, player_thoughts|
        max_messages = player_thoughts.values.map(&:length).max || 1

        (0...max_messages).each do |msg_idx|
          cells = player_display_names.map do |name|
            messages = player_thoughts[name] || []
            msg = messages[msg_idx]
            escaped_msg = msg ? msg.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;') : '&nbsp;'
            "<td>#{escaped_msg}</td>"
          end.join

          turn_cell = msg_idx == 0 ?
            "<td rowspan='#{max_messages}' style='font-weight: bold; background-color: #e8f4f8; vertical-align: top;'>Choose Partners</td>" :
            ""

          rows << "<tr>#{turn_cell}#{cells}</tr>"
        end
      end
    end

    # Then, choose_catch turns
    if organized_thoughts["choose_catch"]
      organized_thoughts["choose_catch"].keys.sort.each do |turn|
        player_thoughts = organized_thoughts["choose_catch"][turn]
        max_messages = player_thoughts.values.map(&:length).max || 1

        (0...max_messages).each do |msg_idx|
          cells = player_display_names.map do |name|
            messages = player_thoughts[name] || []
            msg = messages[msg_idx]
            escaped_msg = msg ? msg.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;') : '&nbsp;'
            "<td>#{escaped_msg}</td>"
          end.join

          turn_cell = msg_idx == 0 ?
            "<td rowspan='#{max_messages}' style='font-weight: bold; background-color: #f0f0f0; vertical-align: top;'>Turn #{turn}</td>" :
            ""

          rows << "<tr>#{turn_cell}#{cells}</tr>"
        end
      end
    end

    # Generate header
    header_cells = player_display_names.map { |name| "<th>#{name}</th>" }.join

    <<~HTML
      <div class="thoughts">
        <table>
          <thead>
            <tr>
              <th style="width: 150px;">Phase/Turn</th>
              #{header_cells}
            </tr>
          </thead>
          <tbody>
            #{rows.join("\n")}
          </tbody>
        </table>
      </div>
    HTML
  end
end
