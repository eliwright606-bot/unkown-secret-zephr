# Chess Assistant

On-device chess move assistant for the Chess.com iOS app, running the [Rodent V](https://github.com/nescitus/Rodent-V) engine (by Naman Thanki & Pawel Koziol) with the **Nimzoid personality** permanently loaded. Suggestions are drawn as arrows on the board.

Everything runs locally on the device. No network requests, and no move data leaves your phone.

## Features

- **Rodent V + Nimzoid personality** — likes closed positions, restricts the opponent's mobility and hunts the enemy king, with the Nimzowitsch opening book. The NNUE net and book are embedded in the tweak itself.
- **Search depth slider (1–15)** — depth-based strength instead of engine ELO. Deeper = stronger.
- Up to 3 candidate arrows, each labeled with its own eval
- Centipawn or win percentage on the floating button
- Move Analysis grades every move you play from Brilliant to Blunder, tracks accuracy, and shows the full breakdown in the settings panel
- **Auto Play** answers for you once your opponent moves. Adjustable delay (0–5 s) with optional jitter and a 2nd-move chance
- **⚡ Instant Mates** — the moment a mate is available, it is played at once (~0.1 s)
- **↩ Auto Recapture (0.1 s)** — when the opponent takes one of your pieces, the recapture is played instantly
- **🚩 Flag Mode** — when your clock drops under 10 seconds, every auto move fires at ~0.1 s (no delay, no jitter, no second-best)
- **⏩ Premove** — drag a move while it's the opponent's turn; when your turn arrives the move is validated against the legal move list and played instantly
- Long-press the floating ♟ button to pause or resume the assistant right away
- Live detection of about 40 openings, including the Ruy Lopez, Najdorf, Caro-Kann and Queen's Gambit, shown in the panel
- One tap copies the current FEN to your clipboard
- Accuracy stats, move grades and opening tracking reset when a game ends, detected on-device from checkmate or stalemate
- Arrow styling: color by eval or solid green, thin to thick shafts, adjustable opacity
- A ⚡ button that applies safer settings in one tap (depth 8, Auto Play off)

Works in online games, bot games and puzzles.

## Install

### Jailbroken (rootless)

Add the repo in Sileo or Zebra and install:

```
https://itzzace.github.io/chess-assistant/
```

Respring after installing, then open Chess.com.

### TrollStore (no jailbreak)

Download the iOS 16 or 17 IPA from the [releases page](https://github.com/itzzace/chess-assistant/releases) and sideload it with TrollStore.

## Usage

1. Open Chess.com and start any game.
2. Tap the floating ♟ button to open the settings panel. Long-press it to pause or resume instantly.
3. Pick a search depth and toggle Auto Play, Auto Recapture, Premove, Flag Mode or Instant Mates as you like. The ⚡ button applies safer settings for you.
4. Arrows appear on the board when it's your turn. With Auto Play on, the move gets played for you.

Debug Log in the panel shows recent events such as FEN detection, engine responses and which hooks installed. FEN copies the current position.

> Warning: using an assistant breaks Chess.com's fair-play policy and can get your account banned.

## Building

Requires [Theos](https://theos.dev) and a Go toolchain. CI does all of this automatically — see [.github/workflows/build.yml](.github/workflows/build.yml):

```bash
# clone the engine and add the bridge
git clone --depth 1 https://github.com/nescitus/Rodent-V.git rodent
cp rodent_bridge.go rodent/

# cross-compile Rodent V for iOS arm64 into a static archive
SDK=$(xcrun -sdk iphoneos --show-sdk-path)
cd rodent
GOOS=ios GOARCH=arm64 CGO_ENABLED=1 \
  CC=$(xcrun -sdk iphoneos --find clang) \
  CGO_CFLAGS="-arch arm64 -isysroot $SDK -miphoneos-version-min=15.0" \
  CGO_LDFLAGS="-arch arm64 -isysroot $SDK -miphoneos-version-min=15.0" \
  go build -buildmode=c-archive -o librodent.a .
cp librodent.a librodent.h ..

# stage the Nimzoid net + book for embedding (the Makefile puts both into the dylib)
cp rodent/nets/rodent_4kb_768hl_8ob_v2.bin rodent_net.bin
cp rodent/books/nimzowitsch.bin rodent_book.bin

# build the deb
make package FINALPACKAGE=1
```

## Project layout

| File | Purpose |
|------|---------|
| `Tweak.xm` | Main tweak: board/FEN detection, arrow rendering, settings UI, auto play, premove, recapture, flag mode |
| `engine.mm` | Rodent V wrapper: UCI over redirected Go pipes, Nimzoid personality, FEN legality, legal-move enumeration |
| `engine.h` | Engine interface used by the tweak |
| `rodent_bridge.go` | Go side of the bridge, appended to the Rodent V checkout at build time |
| `web/` | Landing page / repo site |
| `Makefile` | Theos tweak build (`com.chess.assistant`, rootless) |
| `.github/workflows/` | CI: builds librodent.a + .deb, publishes releases & apt repo |

## Credits

- Made by @epicccccc ([YouTube](https://youtube.com/@epicccccc), Discord: `itzzace.`)
- [Rodent V](https://github.com/nescitus/Rodent-V) by Naman Thanki and Pawel Koziol, based on Sungorus 1.4 by Pablo Vazquez
- Nimzoid personality by Pawel Koziol
