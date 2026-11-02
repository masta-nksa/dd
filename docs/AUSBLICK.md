# Doppelfaust (Godot) – Ausblick

Stand: 2026-11-02. Gerüst angelegt, **noch nie in Godot geöffnet oder getestet** (Godot-Download war in der Sitzung gesperrt).

## Stufen
1. Gerüst (Projekt, Eingabe, Menü, Pause, Web-Export) – Projektdatei und Workflow angelegt, Eingabe nur für 1P-Bewegung
2. 2.5D-Kern: `CharacterBody3D`/Node2D mit X, Z (Spur), Y (Sprung), Z-Sortierung, Schatten, Kamera für beide Spieler
3. Kampf: `HitBox`/`HurtBox` (Area), Combos, Spezial, Rückstoss; Angriffe als Daten (`Resource`)
4. Gegner-KI (FSM), vier Typen, Boss, Wellen, Level mit Parallax
5. Waffen Stufe 1 (Greifen, Werfen, Schläger, Kisten, Drops)
6. Töne, HUD, Game-Over/Sieg, Rekord
7. Kämpferwahl (Kai, Ria, Bruno, Mika), danach feinere Grafik (Sprites)

## Online-Koop (später, eigener Konzeptvorschlag nötig)
- Node.js-WebSocket-Relay auf Fly.io; Räume mit Code; Godot `WebSocketMultiplayerPeer` + `@rpc`.
- Host-autoritativ: ein Client simuliert die Welt, der andere sendet Eingaben; Client-Prediction nur für die eigene Figur, getrennt vom Spielzustand.
- Offene Fragen: Latenz-Toleranz, Wiederverbinden, Spielerzahl (nur 2?).

## Nächste Schritte
- Godot 4.4.x installieren lassen (oder lokal öffnen) und das Gerüst testen.
- Danach Stufe 2.
