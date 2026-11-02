# Doppelfaust (Godot) – Ausblick

Stand: 2026-11-02. Stufen 1–4 fertig und headless getestet (`tests/stufe2_test.gd`, `stufe3_test.gd`, `stufe4_test.gd`).
Start: `godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe4_test.gd` (ohne `--fixed-fps` läuft er in Echtzeit, ~10 min).
Balance-Messung: Parameter `-- normal` (Bot ist sterblich). Web-Export noch nicht lokal getestet (Export-Templates fehlen).

## Stufe 3 (Kampf) – Aufbau
- `scripts/combat/`: `AttackData` (Daten), `Attacks` (Tabelle: punch1–3, kick, spin, jump_kick), `HitBox`, `HurtBox` (Quader x/y/z),
  `CombatSystem` (prüft aktive HitBoxen gegen HurtBoxen anderer Teams, jeder Angriff trifft ein Ziel nur einmal).
- `Fighter`: FSM IDLE, WALK, JUMP, ATTACK, HIT, KNOCKDOWN, GETUP, DEAD; Eingabepuffer 0,25 s; Combo startet in der Erholung;
  Trefferpause 0,07 s; Rückstoss; Umwerfen mit Unverwundbarkeit am Boden; Spezial «spin» kostet 4 LP.
- Steuerung: 1P F = Schlag, G = Tritt, R = Spezial; 2P K, L, I. F1 zeigt Hit- (rot) und Hurtboxen (grün).
- Trainingspuppe (Team 1) in `main.gd`, steht nach 2,5 s wieder auf; wird in Stufe 4 durch Gegner ersetzt.
- Offen: Controller, Pause, Spezial-Kombination F+G, Greifen (Stufe 5).

## Stufen
1. Gerüst (Projekt, Eingabe, Menü, Pause, Web-Export) – Projektdatei und Workflow angelegt; Menü und Pause fehlen noch
2. 2.5D-Kern: `CharacterBody3D`/Node2D mit X, Z (Spur), Y (Sprung), Z-Sortierung, Schatten, Kamera für beide Spieler
3. Kampf: `HitBox`/`HurtBox` (Area), Combos, Spezial, Rückstoss; Angriffe als Daten (`Resource`)
4. Gegner-KI (FSM), vier Typen, Boss, Wellen, Level mit Parallax
5. Waffen Stufe 1 (Greifen, Werfen, Schläger, Kisten, Drops)
6. Töne, HUD, Game-Over/Sieg, Rekord
7. Kämpferwahl (Kai, Ria, Bruno, Mika), danach feinere Grafik (Sprites)

## Stufe 4 (Gegner) – Aufbau
- `scripts/enemies/enemy.gd` (`Enemy extends Fighter`): KI-Zustände LURK, CHASE, ATTACK, RETREAT, HURT, DEAD; vier Typen
  (`thug` Schläger, `dasher` Flitzer, `brute` Brocken, `boss` Granit) mit Werten aus dem Pygame-Spiel; Boss mit Anlauf-Rammen.
- Gegnerangriffe `g_*` in `Attacks`; neu in `AttackData`: `drive` (Rammen), `chain_needs_hit`. `Fighter` bekam `body_scale`, `weight`, `score`.
- `scripts/core/wave_director.gd`: fünf Wellen wie im Pygame-Spiel (Level 5400 breit), Nachrücken, Extras bei 2 Spielern,
  höchstens 2 Angreifer pro Spieler von beiden Seiten, tote Gegner verschwinden nach 1,6 s. Kamera bleibt während einer Welle stehen.
- HUD: Banner «WELLE n», «LOS >>>», Punkte, «GESCHAFFT!» / «GAME OVER».
- Tests: 6 Bot-Läufe (1 und 2 Spieler, 3 Zufallswerte) bis zum Levelende ohne Softlock (76–95 s).
- Balance: Der einfache Bot (Dauerfeuer) gewinnt 28 von 28 sterblichen Läufen mit 48–80 LP Rest; ein Mensch spielt anders.
  Echte Schwierigkeit bitte von Hand prüfen. Nicht portiert: Hindernis-Umweg (`umweg`), weil es noch keine Kisten gibt (Stufe 5).

## Online-Koop (später, eigener Konzeptvorschlag nötig)
- Node.js-WebSocket-Relay auf Fly.io; Räume mit Code; Godot `WebSocketMultiplayerPeer` + `@rpc`.
- Host-autoritativ: ein Client simuliert die Welt, der andere sendet Eingaben; Client-Prediction nur für die eigene Figur, getrennt vom Spielzustand.
- Offene Fragen: Latenz-Toleranz, Wiederverbinden, Spielerzahl (nur 2?).

## Nächste Schritte
- Stufe 5: Waffen (Greifen, Werfen, Schläger, Kisten, Drops) und Requisiten.
