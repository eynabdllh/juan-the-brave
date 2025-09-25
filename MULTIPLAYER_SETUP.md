# LAN Multiplayer Setup Instructions

This document provides step-by-step instructions for setting up the LAN multiplayer architecture in Godot 4.

## Overview

The multiplayer system uses ENetMultiplayerPeer with a peer-to-peer topology where one instance acts as server/host and others connect as clients within the same local network.

## Files Created

1. `scripts/multiplayer_manager.gd` - Main multiplayer logic and connection handling
2. `scripts/networked_player.gd` - Networked player with synchronization
3. This setup guide

## Scene Setup Instructions

### 1. Create Main Multiplayer Scene

**YOU SHOULD DO THIS:** Create a new scene called `multiplayer_lobby.tscn` with the following structure:

```
Node2D (root) - Attach script: scripts/multiplayer_manager.gd
├── MultiplayerSpawner
├── MultiplayerSynchronizer
└── UI (CanvasLayer)
    ├── VBoxContainer
    │   ├── StatusLabel (Label)
    │   ├── HSeparator
    │   ├── HBoxContainer
    │   │   ├── HostButton (Button) - Text: "Host Game"
    │   │   └── JoinButton (Button) - Text: "Join Game"
    │   └── IPInput (LineEdit) - Placeholder: "Enter Host IP Address"
```

**Configuration Details:**

- **MultiplayerSpawner:**
  - Set `Spawn Path` to `.` (current node)
  - Leave `Spawnable Scenes` empty for now (will be set via script)

- **MultiplayerSynchronizer:**
  - Set `Root Path` to `.` (current node)
  - Set `Replication Interval` to 0.05 (20 FPS sync rate)

- **UI Layout:**
  - Position the VBoxContainer in the center of the screen
  - Set appropriate margins and spacing for a clean layout
  - StatusLabel should be large enough to display connection status

### 2. Create Networked Player Scene

**YOU SHOULD DO THIS:** Create a new scene called `networked_player.tscn` based on your existing `player.tscn`:

1. **Duplicate** your existing `player.tscn` and rename it to `networked_player.tscn`
2. **Replace** the script on the root CharacterBody2D node with `scripts/networked_player.gd`
3. **Add** a MultiplayerSynchronizer node as a child of the root node

**MultiplayerSynchronizer Configuration:**
- Set `Root Path` to `.` (current node)
- Set `Replication Interval` to 0.05
- The script will automatically configure synchronized properties

### 3. Configure Multiplayer Manager

**YOU SHOULD DO THIS:** In the `multiplayer_lobby.tscn` scene:

1. Select the root Node2D
2. In the Inspector, find the `Player Scene` export variable
3. Assign the `networked_player.tscn` scene to this property

### 4. Update Project Settings

**YOU SHOULD DO THIS:** Add the multiplayer lobby to your project:

1. Open Project Settings
2. Go to Application > Run
3. Either:
   - Set `Main Scene` to `multiplayer_lobby.tscn` for direct multiplayer testing, OR
   - Add a button to your existing main menu that loads the multiplayer scene

## Usage Instructions

### Starting a Server (Host)

1. Run the game
2. Click "Host Game"
3. The status will show your local IP address and port
4. Share this IP with other players on your LAN

### Joining as Client

1. Run the game on another machine
2. Enter the host's IP address in the text field
3. Click "Join Game"
4. You should connect and see both players

## Network Architecture Details

### Connection Flow

1. **Server Initialization:**
   - Creates ENetMultiplayerPeer server
   - Binds to port 7000 on all interfaces
   - Spawns host player immediately
   - Waits for client connections

2. **Client Connection:**
   - Creates ENetMultiplayerPeer client
   - Connects to specified host IP:7000
   - Receives player spawn from server
   - Begins synchronization

### Synchronization

- **Position & Velocity:** Real-time sync at 20 FPS
- **Animations:** State-based sync (walk, idle, attack)
- **Combat:** RPC-based damage dealing
- **Authority:** Each player controls their own character

### Signal Handling

The system handles these multiplayer events:
- `peer_connected` - New player joins
- `peer_disconnected` - Player leaves
- `connection_failed` - Client connection fails
- `server_disconnected` - Server shuts down

## Testing

### Local Testing
1. Run two instances of the game
2. Host on one, join with 127.0.0.1 on the other
3. Both players should appear and move independently

### LAN Testing
1. Find host machine's IP address (`ipconfig` on Windows, `ifconfig` on Linux/Mac)
2. Ensure port 7000 is not blocked by firewall
3. Connect from other machines using the host IP

## Troubleshooting

### Common Issues

1. **Connection Failed:**
   - Check firewall settings
   - Verify IP address is correct
   - Ensure both machines are on same network

2. **Players Not Syncing:**
   - Check MultiplayerSynchronizer configuration
   - Verify script is attached correctly
   - Look for errors in debug console

3. **Port Already in Use:**
   - Change DEFAULT_PORT in multiplayer_manager.gd
   - Restart both host and client

### Debug Information

The system prints debug information to console:
- Connection status changes
- Peer connect/disconnect events
- Player spawn/despawn events
- Network errors

## Extension Points

The modular design allows easy extension:

1. **Game Modes:** Add different spawning logic in multiplayer_manager.gd
2. **More Sync Properties:** Add to networked_player.gd sync variables
3. **Chat System:** Add UI and RPC calls for messaging
4. **Lobby System:** Extend UI for player lists and game settings
5. **Reconnection:** Add logic to handle temporary disconnections

## Security Considerations

This is a basic LAN implementation. For production use, consider:
- Input validation and sanitization
- Rate limiting for RPCs
- Cheat detection and prevention
- Encrypted connections for sensitive data
