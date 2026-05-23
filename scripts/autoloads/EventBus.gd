extends Node

# Cross-system events only

@warning_ignore("unused_signal")
# Example: Emitted when the game ends, caught by UI and Audio
signal game_over

@warning_ignore("unused_signal")
# Example: Emitted when score changes, caught by UI
signal score_updated(new_score: int)

@warning_ignore("unused_signal")
# Example: Emitted to request playing a specific sound
signal play_sfx(sfx_name: String)
