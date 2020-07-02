# Arcade Machines

## Developer information

See `lua/arcademachine_games/test/testgame.lua` for an example minimal game implementation.

For development your script must return a function to prevent errors when running via luadev. Once ready for release, your script must return the game table.

You can assign the function to a global variable (e.g. `TESTGAME`) and call `machine:SetGame(TESTGAME)` on the client to test your game.

### Required methods/properties

Your game table must contain the `Name` property.

Your game must implement the following methods:

* `Update()`
* `Draw()`
* `OnStartPlaying(ply)`
* `OnStopPlaying(ply)`

### Optional methods

* `Init()`
* `Destroy()`
* `DrawMarquee()`
* `OnCoinsInserted(ply, old, new)`
* `OnCoinsLost(ply, old, new)`
    
### Available globals

* `MACHINE`
* `SCREEN_WIDTH`
* `SCREEN_HEIGHT`
* `MARQUEE_WIDTH`
* `MARQUEE_HEIGHT`

### Coins

The machine has its own internal coin count. You can query this count with `MACHINE:GetCoins()` to determine if the player should be allowed to continue playing or showing the coins remaining.

When the player inserts a coin, if the server implements the `Player:TakeCoins(amount)` method then the arcade machine will attempt to take the amount of coins defined by the networked data table variable `MSCoinCost`. This can be changed on the server per machine with `ent:SetMSCoinCost(amount)` and is shown to the player whenever they enter the machine.

Your `OnCoinsInserted` method will then be called with the player who inserted coins, the old coin amount and the new amount.

Similarly, when a coin is "used" the method `OnCoinsLost` will be called with the same arguments.

You can take a given number of coins from the machine using `MACHINE:TakeCoins(amount)`. Be aware that because this sends a netmessage to the server to update the networked variable it takes time for the coin amount to actually change and for `OnCoinsLost` to be called, so do not call `TakeCoins` and then immediately check to see if the player can play - do this check in `OnCoinsLost`.

### Helper libraries

Each instance of the same game will receive the same copy of libraries, so that things such as assets
which should be the same between all instances of a game are not reloaded unneccessarily.

`SetGame` also takes an optional second boolean parameter to forcefully reload all libraries for development purposes.

#### Images

Used for loading images dynamically from the web as usable `Material`s.

`IMAGE:LoadFromURL(url, name, noCache = false)`

`noCache` can be used during development to bypass the built in caching mechanism.

Access your image with `IMAGE.Images[name]`, which will look like

```lua
{
    status = (0 = STATUS_LOADING, 1 = STATUS_LOADED, 2 = STATUS_ERROR),
    mat = Material -- if not yet loaded then error material is used
}
```

#### Sounds

`SOUND:LoadFromURL(url, name, callback)`

`callback`, if defined, is passed the created `IGModAudioChannel`. This can be used for example to enable looping.

To access your sound use `SOUND.Sounds[name]`, which will look like

Sounds that are loaded via `LoadFromURL` are queued in order to prevent performance issues when lots of instances of the same game all load their sounds at once. Where possible, try to load your sounds in `OnStartPlaying` and not in `Init`. You should always be checking that the sound you are trying to play `IsValid` before playing it. Subsequent calls to `LoadFromURL` will not do anything if the requested sound has already been queued/loaded.

```lua
{
    status = (0 = STATUS_QUEUED, 1 = STATUS_LOADING, 2 = STATUS_LOADED, 3 = STATUS_ERROR),
    err = "BASS_SOMEERROR", -- if status == STATUS_ERROR
    sound = IGModAudioChannel -- if status == STATUS_LOADED
}
```

#### Collisions

A simple collision library using a mixture of methods including SAT (Separating Axis Theorem) for polygons.

Available types:

* COLLISION_TYPE_BOX
* COLLISION_TYPE_CIRCLE
* COLLISION_TYPE_POLY

Supported collision checks:

* Box - Box (no rotation, for rotation use Poly - Poly)
* Circle - Circle
* Circle - Poly
* Poly - Poly

`COLLISION:IsColliding(objA, objB)`

Only convex polygons are supported.

Objects passed to `IsColliding` must look like:

```lua
{
    pos = Vector(),
    ang = Angle(),
    collision = {
        type = COLLISION.types.COLLISION_TYPE_BOX, -- see types above
        width = 5, -- if COLLISION_TYPE_BOX
        height = 5, -- if COLLISION_TYPE_BOX
        radius = 5, -- if COLLISION_TYPE_CIRCLE
        vertices = { -- if COLLISION_TYPE_POLY
            Vector(),
            Vector(),
            Vector(),
            ...
        }
    }
}
```

### Thanks

* Robro - for the model
* Sera - for help with environment wrapping stuff
* Python1320 - for help with clientside material override workaround
* Twistalicky - various ideas/suggestions
* All the people who have made/are making games for the machine e.g. twentysix, Cynthia
* Anyone else I forgot