# Doppelfaust (Godot) – Hinweise für Claude

2.5D-Koop-Beat-'em-up als Webgame (GitHub Pages). Portierung von `masta-nksa/spiel-team-3` (Python/pygame) nach Godot.
Lies zuerst `docs/AUSBLICK.md`.

## Technik
- Engine: Godot 4.x, **GDScript** (C# lässt sich in Godot 4 nicht ins Web exportieren).
- Export: HTML5/WebAssembly, **Single-Threaded** (kein Cross-Origin-Isolation-Header auf GitHub Pages möglich).
- Backend (später): Node.js-WebSocket-Relay auf Fly.io.

## Konventionen
- Achsen: **X** = horizontal, **Z** = Tiefe/Spur, **Y** = Sprung/Höhe. (Anders als im Pygame-Spiel: dort y = Tiefe, z = Höhe.)
- Nodes: PascalCase (`PlayerController`, `HitBox`, `HurtBox`). Skripte/Variablen: snake_case (`current_health`, `is_attacking`).
- Zustände: Finite State Machine für Combos, Treffer und Fortbewegung.
- Netzwerk: High-Level `@rpc` bzw. WebSocket-Nachrichten; Client-Prediction von Spielzustand getrennt halten.
- Sprache: Chat, Kommentare und Commits Deutsch; Bezeichner Englisch (siehe oben).

## Arbeitsregeln
- Entwicklung auf `claude/blissful-brown-u9q28c`, fertige Stufen per Fast-Forward nach `main`. Keinen Pull Request, ausser verlangt.
- Bei grösseren Features zuerst Konzept als Liste, auf Antwort warten.
- Keine Binärdateien, `.godot/`, `build/` committen.
