# LAN Multiplayer Architecture Documentation

## Overview

This implementation provides a complete LAN multiplayer system for Godot 4 using ENetMultiplayerPeer with peer-to-peer topology. One instance operates as server/host while others connect as clients within the same local network.

## Architecture Components

### 1. MultiplayerManager (`scripts/multiplayer_manager.gd`)

**Purpose:** Central coordinator for all multiplayer functionality

**Key Responsibilities:**
- Initialize ENetMultiplayerPeer for server and client modes
- Handle connection lifecycle (connect, disconnect, failures)
- Manage peer discovery and spawning
- Provide UI feedback and status updates

**Core Functions:**

```gdscript
_start_server()           # Initialize server on port 7000
_connect_to_server(ip)    # Connect client to host IP
_spawn_player(peer_id)    # Create networked player instance
_reset_network()          # Clean up connections and state
```

**Signal Handling:**
- `peer_connected` → Spawn player for new peer
- `peer_disconnected` → Remove player and update UI
- `connection_failed` → Reset and show error
- `server_disconnected` → Client-side cleanup

### 2. NetworkedPlayer (`scripts/networked_player.gd`)

**Purpose:** Player entity with multiplayer synchronization

**Key Features:**
- Extends existing player functionality with network sync
- Uses MultiplayerSynchronizer for automatic property replication
- Implements authority-based input handling
- Provides RPC-based combat system

**Synchronized Properties:**
```gdscript
sync_position: Vector2    # Player world position
sync_velocity: Vector2    # Movement velocity
sync_animation: String    # Current animation state
sync_flip_h: bool        # Sprite horizontal flip
```

**Authority Model:**
- Each player has authority over their own character
- Input processing only on local player
- State replication to all other peers
- RPC calls for actions affecting other players

### 3. Scene Structure

#### Multiplayer Lobby Scene
```
Node2D (MultiplayerManager)
├── MultiplayerSpawner     # Handles player instantiation
├── MultiplayerSynchronizer # Root-level synchronization
└── UI (CanvasLayer)       # User interface
    ├── StatusLabel        # Connection status display
    ├── HostButton         # Start server
    ├── JoinButton         # Connect to server
    └── IPInput           # Host IP address input
```

#### Networked Player Scene
```
CharacterBody2D (NetworkedPlayer)
├── MultiplayerSynchronizer # Player state sync
├── AnimatedSprite2D       # Visual representation
├── CollisionShape2D       # Physics collision
├── [Camera nodes]         # Local player camera
└── [UI elements]          # Health, prompts, etc.
```

## Network Protocol

### Connection Flow

1. **Server Initialization:**
   ```
   Host clicks "Host Game"
   → Create ENetMultiplayerPeer server
   → Bind to port 7000, max 4 clients
   → Set multiplayer.multiplayer_peer
   → Spawn host player (peer ID 1)
   → Display local IP for sharing
   ```

2. **Client Connection:**
   ```
   Client enters host IP and clicks "Join Game"
   → Create ENetMultiplayerPeer client
   → Connect to host_ip:7000
   → Set multiplayer.multiplayer_peer
   → Wait for server acknowledgment
   → Receive player spawn from server
   ```

3. **Player Spawning:**
   ```
   Server receives peer_connected signal
   → Create networked_player instance
   → Set multiplayer authority to peer_id
   → Add to scene tree with unique name
   → Position at spawn point
   ```

### Synchronization Strategy

**Real-time Sync (20 FPS):**
- Position and velocity for smooth movement
- Animation state for visual consistency
- Sprite orientation (flip_h)

**Event-based Sync (RPC):**
- Attack actions and damage dealing
- Health changes and status effects
- Interactive events (doors, items, etc.)

**Authority Distribution:**
- Each player controls their own character
- Server authoritative for spawning/despawning
- Peer-to-peer for direct interactions

## Implementation Details

### ENetMultiplayerPeer Configuration

```gdscript
# Server setup
peer = ENetMultiplayerPeer.new()
peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
multiplayer.multiplayer_peer = peer

# Client setup  
peer = ENetMultiplayerPeer.new()
peer.create_client(host_ip, DEFAULT_PORT)
multiplayer.multiplayer_peer = peer
```

### MultiplayerSynchronizer Setup

```gdscript
# Automatic property synchronization
sync_node.add_property("sync_position")
sync_node.add_property("sync_velocity")
sync_node.add_property("sync_animation")
sync_node.add_property("sync_flip_h")
sync_node.set_multiplayer_authority(player_id)
```

### RPC Implementation

```gdscript
# Attack synchronization
@rpc("any_peer", "call_local", "reliable")
func _perform_attack(attack_direction: String):
    # Execute attack animation on all clients

# Damage application
@rpc("any_peer", "call_local", "reliable") 
func take_damage(amount: int, attacker_id: int):
    # Apply damage and effects across network
```

## Performance Considerations

### Network Optimization

1. **Sync Rate:** 20 FPS (0.05s interval) balances smoothness and bandwidth
2. **Property Selection:** Only essential properties are synchronized
3. **RPC Usage:** Events use reliable RPCs, frequent updates use unreliable
4. **Interpolation:** Remote players use lerp for smooth position updates

### Memory Management

1. **Player Cleanup:** Automatic removal on disconnect
2. **Peer Tracking:** Array-based peer management
3. **Scene Lifecycle:** Proper cleanup in _exit_tree()

## Security Considerations

### Current Implementation
- Basic LAN-only design
- No encryption or authentication
- Trust-based peer communication
- Local network isolation provides basic security

### Production Recommendations
- Input validation and sanitization
- Rate limiting for RPC calls
- Cheat detection mechanisms
- Encrypted connections for sensitive data
- Server-authoritative validation

## Testing and Debugging

### Local Testing
```bash
# Run two instances
Instance 1: Click "Host Game"
Instance 2: Enter "127.0.0.1", click "Join Game"
```

### LAN Testing
```bash
# Find host IP
Windows: ipconfig
Linux/Mac: ifconfig

# Ensure firewall allows port 7000
# Connect from other machines using host IP
```

### Debug Information
- Console logging for all network events
- Status label shows real-time connection state
- Error messages for connection failures
- Peer count and ID tracking

### Test Script Usage
```gdscript
# Attach multiplayer_test.gd to any node
# Automatically runs validation tests
# Provides manual test functions
```

## Extension Guidelines

### Adding New Synchronized Properties

1. Add property to networked_player.gd:
   ```gdscript
   @export var sync_new_property: Type
   ```

2. Update _setup_multiplayer_sync():
   ```gdscript
   sync_node.add_property("sync_new_property")
   ```

3. Handle in _update_sync_properties() and _apply_sync_properties()

### Adding New RPC Functions

1. Define RPC function:
   ```gdscript
   @rpc("any_peer", "call_local", "reliable")
   func new_network_action(param1, param2):
       # Implementation
   ```

2. Call from local player:
   ```gdscript
   if is_local_player:
       rpc("new_network_action", value1, value2)
   ```

### Adding Game Modes

1. Extend MultiplayerManager with mode-specific logic
2. Modify spawn points and player configuration
3. Add UI for mode selection
4. Implement mode-specific rules and win conditions

## Troubleshooting Guide

### Common Issues

**"Connection Failed"**
- Check firewall settings (port 7000)
- Verify IP address accuracy
- Ensure same network connectivity
- Try localhost (127.0.0.1) for local testing

**"Players Not Syncing"**
- Verify MultiplayerSynchronizer configuration
- Check script attachment on player scene
- Look for console errors
- Validate scene structure matches template

**"Port Already in Use"**
- Change DEFAULT_PORT in multiplayer_manager.gd
- Restart both host and client applications
- Check for other applications using port 7000

**"Player Spawning Issues"**
- Ensure player_scene is assigned in inspector
- Verify networked_player.tscn exists and is valid
- Check MultiplayerSpawner configuration
- Look for script errors in networked_player.gd

### Debug Commands

```gdscript
# In debug console or test script
multiplayer_test.get_network_info()     # Show network status
multiplayer_test.test_local_connection() # Test connection
multiplayer_test.run_tests()            # Full system validation
```

## Performance Metrics

### Bandwidth Usage (Estimated)
- Per player: ~2-4 KB/s for position/animation sync
- 4 players: ~16 KB/s total network traffic
- RPC events: Minimal additional overhead

### Latency Requirements
- LAN: <10ms typical
- Sync rate: 50ms (20 FPS)
- Input responsiveness: <100ms end-to-end

### Scalability Limits
- Current: 4 players maximum
- Network: Limited by LAN bandwidth
- Processing: Minimal CPU overhead per player
- Memory: ~1-2 MB per networked player

This implementation provides a solid foundation for LAN multiplayer gaming with room for extensive customization and feature additions.
