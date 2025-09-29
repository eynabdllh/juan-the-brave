extends Node

signal player_health_changed(player_id, health)
signal player_max_health_changed(player_id, max_health)

var player_stats = {}

func register_player(player_id, initial_health=100, initial_max_health=100):
    if not player_stats.has(player_id):
        player_stats[player_id] = {
            "health": initial_health,
            "max_health": initial_max_health
        }
    player_health_changed.emit(player_id, player_stats[player_id].health)
    player_max_health_changed.emit(player_id, player_stats[player_id].max_health)

func unregister_player(player_id):
    if player_stats.has(player_id):
        player_stats.erase(player_id)

@rpc("any_peer", "call_local", "reliable")
func update_health(player_id, new_health):
    if player_stats.has(player_id):
        player_stats[player_id].health = new_health
        player_health_changed.emit(player_id, new_health)

func get_health(player_id):
    if player_stats.has(player_id):
        return player_stats[player_id].health
    return 0
