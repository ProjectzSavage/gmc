# gmc
Guess my country is a almost perfect copy of the roblox game guess my number. The difference is instead of guessing my number, it's my country. Read scripts to understand the mechanics further.

🎮 Game Concept
A 1v1 Deduction Game (inspired by Guess My Number).
Two players (or 1 Player vs. Bot) sit at a table. They each pick a secret Letter and a secret Country (starting with that letter). They take turns guessing the opponent's secret.

First to guess the opponent's Country wins.

Workspace
└── Tables (Folder)
    └── TableModel (Model)
        ├── SeatA (Seat)
        ├── SeatB (Seat)
        └── TableTop (Part) -- ProximityPrompts should appear here

StarterGui
└── GameGui (ScreenGui)
    ├── WaitF (ScreenGui elements for waiting turns)
    ├── LPickF (Letter Pick UI)
    ├── CPickF (Country Pick UI)
    ├── LGuessF (Letter Guess UI)
    ├── CGuessF (Country Guess UI)
    └── StatsFrame (Leaderboard display)

