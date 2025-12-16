# Fishing Pond Game - Team Coding Challenge

## Project Purpose
This is a game theory-based coding challenge for our backend engineering team's weekly meetings. The project serves two goals:
1. **Learn Sorbet**: Engineers will get hands-on practice with Ruby's type checker (Sorbet)
2. **Strategic Thinking**: Explore game theory concepts through an iterated resource management game

Inspired by Robert Axelrod's Iterated Prisoner's Dilemma Tournament, but with dynamic resource management and partner selection mechanics.

## Tech Stack
- **Language**: Ruby 3.x
- **Type System**: Sorbet (strict mode)
- **Testing**: RSpec
- **Output Format**: HTML reports for round summaries

## Game Rules

### Overview
- **Players**: n players (n must be even; if odd, one person sits out)
- **Duration**: n rounds total
- **Objective**: Catch the most fish across all rounds

### Core Mechanics

**Pond Dynamics:**
- Initial pond: 100 fish
- Growth rate: **15%-25% per turn** (randomly varies each turn to add uncertainty)
- Fishing duration: 10 turns per pairing
- Maximum catch per turn: 30 fish per person

**Fishing Rules:**
- Each turn, both players simultaneously decide how many fish to catch (0-30)
- **Success case**: If `player1_catch + player2_catch <= pond_fish`
  - Each player gets their requested catch
  - Remaining fish reproduce: `new_fish = remaining * random_growth_rate` (between 1.15x and 1.25x)
  - The exact growth rate is unpredictable, making optimal strategies harder to calculate
- **Overfishing case**: If `player1_catch + player2_catch > pond_fish`
  - Both players get 0 fish
  - Pond immediately depletes to 0 (game ends early for this pair)

**Pairing System:**
1. **Round 1**: Random pairing
2. **Rounds 2-n**:
   - Each player submits 2 preferred partners (ranked #1 and #2)
   - Matching algorithm:
     - First, match players who mutually selected each other as #1 choice
     - Remaining players are randomly paired
   - Players cannot see others' preferences before submitting their own

**Transparency:**
- After each round, all players' actions are publicly visible:
  - Who paired with whom
  - Each player's catches for all 10 turns
  - Final scores for that round

### Victory Condition
Player with the highest total fish count after n rounds wins.

## Project Structure
```
fishing-pond-game/
├── CLAUDE.md                 # This file
├── Gemfile
├── .sorbet/
│   └── config
├── sorbet/
│   ├── rbi/
│   └── tailor/
├── lib/
│   ├── game/
│   │   ├── tournament.rb     # Main tournament runner
│   │   ├── round.rb          # Single round logic
│   │   ├── pond.rb           # Pond state management
│   │   └── matcher.rb        # Pairing algorithm
│   └── strategy/
│       ├── base_strategy.rb  # Abstract base class
│       └── examples/         # Built-in example strategies
│           ├── conservative.rb
│           ├── greedy.rb
│           └── adaptive.rb
├── strategies/               # User-submitted strategies go here
│   ├── alice_strategy.rb
│   ├── bob_strategy.rb
│   └── ...
├── spec/
│   └── ...
├── bin/
│   ├── play                  # Interactive game runner
│   └── validate              # Validate strategy file
└── reports/                  # Generated HTML reports
    └── round_*.html
```

## Strategy Interface

All player strategies must inherit from `BaseStrategy` and implement two methods:
```ruby
# typed: strict
class BaseStrategy
  extend T::Sig
  extend T::Helpers
  abstract!

  sig { abstract.params(
    round_number: Integer,           # Current round (1 to n)
    turn_number: Integer,            # Current turn in this pairing (1 to 10)
    pond_fish: Integer,              # Fish remaining in pond
    my_history: T::Array[Integer],  # My catches this pairing [5, 6, 4, ...]
    partner_history: T::Array[Integer], # Partner's catches [5, 7, 3, ...]
    partner_name: String,            # Current partner identifier
    all_players_history: T::Hash[String, PlayerHistory] # All players' history
  ).returns(Integer) }
  def choose_catch(round_number, turn_number, pond_fish, my_history, partner_history, partner_name, all_players_history)
  end

  sig { abstract.params(
    round_number: Integer,
    all_players: T::Array[String],   # List of all player names
    all_players_history: T::Hash[String, PlayerHistory]
  ).returns([String, String]) }      # Returns [first_choice, second_choice]
  def choose_partners(round_number, all_players, all_players_history)
  end
end

class PlayerHistory < T::Struct
  const :partners, T::Array[String]           # Partners each round
  const :catches, T::Array[T::Array[Integer]] # Catches per round [[5,6,4,...], ...]
  const :scores, T::Array[Integer]            # Total score per round
end
```

**Constraints:**
- `choose_catch` must return 0-30
- `choose_partners` must return 2 distinct names from `all_players` (excluding self)
- Round 1 doesn't call `choose_partners` (random pairing)

## Execution Modes

### Interactive Mode
```bash
# Start tournament
bin/play --interactive --players strategies/*.rb

# Plays round 1, then pauses
> Round 1 complete. Press Enter to continue, or 'stop' to end...

# Play next 2 rounds
> continue 2

# Play all remaining rounds
> continue all

# Generate report
> report
```

### Batch Mode
```bash
# Play all rounds at once
bin/play --batch --players strategies/*.rb

# Dry run with built-in strategies only
bin/play --dry-run
```

### Validation
```bash
# Validate a strategy file before submitting
bin/validate strategies/my_strategy.rb
```

## HTML Report Format

After each round (or set of rounds), generate `reports/round_N.html` containing:

1. **Round Summary**
   - Pairing results (who played with whom)
   - Mutual selections vs random pairings
   
2. **Turn-by-Turn Breakdown**
   - For each pair, show all 10 turns:
     - Pond fish count
     - Each player's catch
     - Success/overfishing indicator
     - Running scores

3. **Leaderboard**
   - Current total scores
   - Rank changes from previous round

4. **Strategy Insights** (optional)
   - Average cooperation rate
   - Pond depletion rate
   - Most/least trusted players (selection frequency)

## Development Guidelines

### Sorbet Usage
- All files must use `# typed: strict`
- Use `sig` blocks for all method signatures
- Run `srb tc` before committing
- Abstract methods use `abstract!` and `T::Helpers`

### Testing
- Each strategy should be testable in isolation
- Use RSpec for unit tests
- Provide test fixtures with sample `PlayerHistory` data

### Example Strategy Implementations
Include 3-5 built-in strategies for reference:
- **Conservative**: Always catches 3 fish, prefers partners with low average catches
- **Greedy**: Catches maximum possible without exceeding pond, prefers high-scoring partners
- **Tit-for-Tat**: Mirrors partner's previous catch
- **Adaptive**: Adjusts based on pond health (80+ fish = aggressive, <30 = conservative)
- **Punisher**: Catches 4 fish normally, but catches 30 if partner ever exceeded 10

## Key Implementation Details

### Matching Algorithm
```
For round n > 1:
  1. Collect all players' preferences
  2. Find mutual first-choice pairs (A→B as #1, B→A as #1)
  3. Match those pairs
  4. Randomly pair remaining players
  5. If odd number remaining, one gets bye (shouldn't happen with even n)
```

### Edge Cases
- Pond reaches 0 before turn 10: End pairing early, both players score 0 for remaining turns
- Player submits invalid catch (< 0 or > 30): Treat as 0
- Player selects invalid partners: Random assignment for that player

## Weekly Meeting Flow

1. **Monday**: Announce challenge, share CLAUDE.md and example strategies
2. **Friday 5pm**: Deadline for strategy submissions to `strategies/` folder
3. **Weekly meeting**: 
   - Run tournament interactively
   - Discuss surprising outcomes after each round
   - Award "Game Theory Champion" to winner
   - Optional: Show most interesting pairing (e.g., pond collapse, perfect cooperation)

## Success Metrics
- Engineers become comfortable with Sorbet type annotations
- Strategies demonstrate learning from game history
- Discussion reveals interesting game theory concepts (tragedy of commons, reputation, trust)

---

**Note**: There is no single "optimal" strategy—success depends on predicting and responding to other players' behaviors. Strategies that are too conservative lose to moderately greedy opponents, while overly greedy strategies destroy ponds and lose partner selection opportunities.
