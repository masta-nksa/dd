# Doppelfaust (Godot) – Ausblick

Stand: 2026-11-02. Stufen 1–6 fertig und headless getestet (`tests/stufe2_test.gd` bis `stufe6_test.gd`).
Start: `godot --headless --fixed-fps 3000 --disable-vsync -s tests/stufe4_test.gd` (ohne `--fixed-fps` läuft er in Echtzeit, ~10 min).
Balance-Messung: Parameter `-- normal` (Bot ist sterblich). Web-Export noch nicht lokal getestet (Export-Templates fehlen).
Startszene ist `scenes/app.tscn`; Tests der reinen Spielszene laden weiter `scenes/main.tscn`.

## Stufe 3 (Kampf) – Aufbau
- `scripts/combat/`: `AttackData` (Daten), `Attacks` (Tabelle: punch1–3, kick, spin, jump_kick), `HitBox`, `HurtBox` (Quader x/y/z),
  `CombatSystem` (prüft aktive HitBoxen gegen HurtBoxen anderer Teams, jeder Angriff trifft ein Ziel nur einmal).
- `Fighter`: FSM IDLE, WALK, JUMP, ATTACK, HIT, KNOCKDOWN, GETUP, DEAD; Eingabepuffer 0,25 s; Combo startet in der Erholung;
  Trefferpause 0,07 s; Rückstoss; Umwerfen mit Unverwundbarkeit am Boden; Spezial «spin» kostet 4 LP.
- Steuerung: 1P F = Schlag, G = Tritt, R = Spezial; 2P K, L, I. F1 zeigt Hit- (rot) und Hurtboxen (grün).
- Trainingspuppe (Team 1) in `main.gd`, steht nach 2,5 s wieder auf; wird in Stufe 4 durch Gegner ersetzt.
- Offen: Spezial-Kombination F+G.

## Stufen
1. Gerüst (Projekt, Eingabe, Menü, Pause, Web-Export)
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

## Stufe 5 (Waffen und Requisiten) – Aufbau
- `scripts/world/`: `Prop` (Kiste, Fass, Tonne, Laterne; blockieren am Boden, Sprung drüber), `WorldItems` (Register + Waffenverteiler),
  `WeaponData`/`Carry` (Tragedinge), `WeaponPickup`, `Pickup` (Huhn +40, Apfel +15, Geld +1000), `Projectile` (Wurf), `Effects` (Splitter, Texte).
- Greifen: 1P E, 2P J. Nichts in Reichweite → das Getragene wird geworfen. Mit Kiste/Fass/Tonne wirft jede Angriffstaste, kein Sprung, langsamer.
- Schläger: Kette 12/18 (2. wirft um), Homerun (Spezial) kostet 2, 10 Haltbarkeit pro Treffer, Wurf 14 Schaden und kostet 3.
  Kiste 18 + 1,2 s, Fass 24 + Umwerfen, Tonne 12 + 1,0 s; zerbricht beim Wurf. Bei Treffern fällt Schweres zu Boden, Gestorbene lassen Waffen blinkend liegen (8 s).
- Drops (Gegner: Schläger 10 %, Flitzer 12 %, Brocken 30 %; Requisiten: Kiste 22 %, Fass 12 %, Tonne 15 %) mit Bremsen wie im Pygame-Spiel;
  erste Kiste enthält immer einen Schläger. Gegner umgehen Hindernisse (`Enemy._detour`) und benutzen keine Waffen.
- Wurfweite ist kurz (~120 px), wie im Pygame-Spiel (Gravitation 1800 statt 1900). Bekannte Mängel: Fass wirft den Brocken um (Gewicht 1,7 teilt nur den Rückstoss).
- Tests: 26 Prüfungen in `stufe5_test.gd`, Bot-Läufe mit Requisiten (6 von 6 ohne Softlock).

## Stufe 6 (Ablauf, Töne, Controller) – Aufbau
- `scripts/core/app.gd` (`App`, Startszene): Menü → Spiel → Pause/Endbildschirm. `Main` kennt das nicht und meldet nur `run_ended(won)` (Sieg nach 4 s, Niederlage nach 2 s).
- `scripts/ui/`: `Screen` (Grundlage mit echten `Button`, also Maus, Tastatur und Controller), `MenuScreen`, `PauseScreen`, `ResultScreen` (Knöpfe 1 s gesperrt).
- Pause: Esc, P oder Start auf jedem Controller. Wird der Controller eines mitspielenden Spielers getrennt, pausiert das Spiel mit Grund.
- `SaveData`: Rekord als Gesamtpunktzahl, getrennt nach 1 und 2 Spielern, dazu Musik an/aus, in `user://doppelfaust.cfg`.
- `SoundBank`: 14 Geräusche und eine Musikschleife (4 Takte, 8 s) im Code berechnet, Port von `ton.py`; `SoundBank.play(id)` bleibt ohne `App` still. M schaltet die Musik.
- Controller: erster Controller = Spieler 1, zweiter = Spieler 2. A Sprung, X/LB Schlag, B Tritt, Y Spezial, RB Greifen, Stick/Kreuz bewegen. Der Greifen-Hinweis im HUD zeigt dann «RB».
- Tests: 44 Prüfungen in `stufe6_test.gd`. Von Hand zu prüfen: Klang der Töne, echtes Gamepad, Speichern und Ton im Browser. Nicht portiert: Rumble, Einsteigen mitten im Spiel.
- Die Warnung «ObjectDB instances leaked» am Ende von `stufe6_test.gd` kommt von Tonobjekten, die beim sofortigen Beenden noch spielen.

## Online-Koop (später, eigener Konzeptvorschlag nötig)
- Node.js-WebSocket-Relay auf Fly.io; Räume mit Code; Godot `WebSocketMultiplayerPeer` + `@rpc`.
- Host-autoritativ: ein Client simuliert die Welt, der andere sendet Eingaben; Client-Prediction nur für die eigene Figur, getrennt vom Spielzustand.
- Offene Fragen: Latenz-Toleranz, Wiederverbinden, Spielerzahl (nur 2?).

## Nächste Schritte
- Stufe 7: Kämpferwahl (Kai, Ria, Bruno, Mika), danach feinere Grafik.
