# tModLoader Multiplayer Linux Launcher

A one-click shortcut that fixes a long-standing Linux-only tModLoader bug: **Steam
shows you as playing "Terraria" instead of "tModLoader," which breaks Steam
friend invites/joins for your multiplayer sessions** (you can still be hosting a
perfectly working world and lobby — your friends just can't reliably get into it
through Steam's invite/join UI).

This isn't a patch, mod, or modification of any tModLoader file. It's a small
launcher script that starts the game a different way — one that tModLoader's own
code already fully supports — which avoids the bug entirely.

## The problem

Related, still-open upstream reports:
- [tModLoader#4538 — Steam Multiplayer Join Game Masked by Terraria](https://github.com/tModLoader/tModLoader/issues/4538)
- [tModLoader#3202 — Friends Can't Join](https://github.com/tModLoader/tModLoader/issues/3202)
- [tModLoader#4968 — "Playing in tModLoader" is not displayed in steam](https://github.com/tModLoader/tModLoader/issues/4968)

On Linux, when tModLoader is launched normally (via Steam's "Play" button),
Steam's friends list / rich presence reports you as playing **Terraria**
instead of **tModLoader**, essentially 100% of the time. Friends then can't see
a working "Join Game" option for you, or invites route incorrectly.

## Root cause

tModLoader is open source, so this was traced directly in its published code
(patches for tModLoader 1.4.4.9, commit
[`666f699`](https://github.com/tModLoader/tModLoader/tree/666f69962d3bdffde54fc14025f02634965b4e7c)):

1. tModLoader is its own Steam app (`1281930`), separate from Terraria (`105600`).
   The main game process correctly initializes itself with Steam as `1281930`.

2. But on startup, it also spawns a second, internal helper process
   ([`TerrariaSteamClient.cs`](https://github.com/tModLoader/tModLoader/blob/666f69962d3bdffde54fc14025f02634965b4e7c/patches/tModLoader/Terraria/ModLoader/Engine/TerrariaSteamClient.cs)),
   whose job is to verify your Terraria ownership/version and (historically)
   forward Terraria achievement unlocks. That helper deliberately re-initializes
   a **separate Steam session under Terraria's app ID (`105600`)**:

   ```csharp
   Logger.Info("Setting steam app id to " + Steam.TerrariaAppId_t);
   Steam.SetAppId(Steam.TerrariaAppId_t);
   ...
   steamInit = SteamAPI.Init();
   ```

3. Crucially, this helper **doesn't exit after its checks** — it drops into a
   permanent loop and stays alive for your *entire play session*. So for as
   long as you're playing, there are two live Steam sessions open at once: one
   as `1281930` (the real game), one as `105600` (the helper). On Linux, Steam
   appears to consistently resolve "what are they currently playing" in favor
   of whichever one it saw registered first — which, by the code's own
   ordering, is always the `105600` helper (the main process explicitly waits
   for the helper's handshake before finishing its own init). The developers
   are aware something like this happens; there's even a mitigating
   `Thread.Sleep(300)` in the code with a comment about "~5-10% of users"
   hitting this on Windows — it just doesn't fix it on Linux.

4. That helper process is *only ever spawned* when the environment variable
   `SteamClientLaunch=1` is present — which Steam itself sets, but only when
   *it* launches the process (i.e., via the "Play" button):

   ```csharp
   internal static LaunchResult Launch()
   {
       if (Environment.GetEnvironmentVariable("SteamClientLaunch") != "1") {
           Logger.Debug("Disabled. Launched outside steam client.");
           return LaunchResult.Ok;
       }
       ...
   ```

## The fix

**Launch tModLoader's own `start-tModLoader.sh` script directly from a
terminal/shortcut, instead of clicking Play in Steam — with the Steam client
already running in the background.**

Without `SteamClientLaunch=1` in the environment, the `105600`-claiming helper
never spawns at all — there's no second session to lose the race to. The main
game process still correctly identifies itself to Steam as tModLoader, via a
fallback tModLoader already ships for exactly this scenario
([`Steam.SetAppId`](https://github.com/tModLoader/tModLoader/blob/666f69962d3bdffde54fc14025f02634965b4e7c/patches/tModLoader/Terraria/ModLoader/Engine/Steam.cs)):

```csharp
internal static void SetAppId(AppId_t appId)
{
    var steam_appid_path = "steam_appid.txt";
    if (Environment.GetEnvironmentVariable("SteamClientLaunch") != "1" || ...) {
        File.WriteAllText(steam_appid_path, appId.ToString()); // writes "1281930"
        return;
    }
    ...
}
```

This is the same technique any Steamworks game uses to self-identify when
launched outside Steam's own launcher — it's an intentional, supported code
path, not something being exploited or hacked around.

Verified in practice: with this launcher, Steam correctly shows tModLoader as
the running game, and a friend was able to join a hosted world through a
normal Steam invite.

## What you lose (and why it doesn't matter much)

- **Terraria achievement unlocking while playing tModLoader.** In practice this
  already doesn't do anything in current tModLoader — the actual
  `SteamUserStats.SetAchievement()` call is commented out in
  [`AchievementsSocialModule.cs`](https://github.com/tModLoader/tModLoader/blob/666f69962d3bdffde54fc14025f02634965b4e7c/patches/tModLoader/Terraria/Social/Steam/AchievementsSocialModule.cs):
  `//Solxan: Blocks attempts to give steam achievements in tml`. So this isn't
  actually a real loss on current versions.
- **The helper's Terraria ownership/version/Family-Share validation checks.**
  These exist to give a friendly error message if your Terraria install is
  missing, outdated, or Family Shared from someone else. If none of that
  applies to you (you own Terraria directly and keep it updated), skipping the
  check changes nothing about how the game actually runs.
- Steam Cloud sync and Workshop mods are handled by the main game process's own
  Steam session either way, and were unaffected in testing.

This is a workaround for a real, currently-unfixed upstream bug — not a
guaranteed-forever fix. A future tModLoader/Steam update could change this
behavior.

## Requirements

- Linux, with tModLoader installed through Steam (native Steam Linux Runtime,
  not Proton).
- Steam already installed and log-in-capable.

## Install

```bash
git clone https://github.com/PedroZborowski/tmod-multiplayer-linux-launcher.git
cd tmod-multiplayer-linux-launcher
./install.sh
```

This installs:
- `~/.local/bin/launch-tmodloader.sh` — the launcher script
- `~/.local/share/applications/tModLoader-MP-Fix.desktop` — an entry in your
  application menu
- A matching icon on your Desktop, if you have one (`~/Desktop`)

`install.sh` doesn't touch your existing tModLoader/Steam installation at all
— it only adds new files under your home directory.

### If auto-detection doesn't find your tModLoader install

The script searches standard Steam library locations (including any extra
libraries listed in `libraryfolders.vdf`). If it still can't find tModLoader,
point it at the right folder directly:

```bash
TMOD_INSTALL_DIR=/path/to/steamapps/common/tModLoader ~/.local/bin/launch-tmodloader.sh
```

## Usage

Just use the new "tModLoader (Multiplayer Fix)" shortcut (app menu or desktop
icon) instead of launching tModLoader from Steam's library. The script will:

1. Start Steam first if it isn't already running, and wait for it to be ready.
2. Find your tModLoader installation.
3. Launch tModLoader's own `start-tModLoader.sh` directly.

Everything else (mods, worlds, servers, Workshop) behaves exactly as normal —
this only changes *how the process gets started*.

## Uninstall

```bash
./uninstall.sh
```

Removes the script and shortcuts. Your Steam/tModLoader installation and
saves are never touched by either script.

## Disclaimer

This is an independent, community workaround for a bug in tModLoader's Linux
build, based on reading tModLoader's own published source code. It is not
affiliated with, endorsed by, or supported by Re-Logic or the tModLoader team.
Use at your own discretion.
