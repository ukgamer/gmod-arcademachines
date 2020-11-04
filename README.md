# Arcade Machines

**Please read [CONTRIBUTING](https://github.com/ukgamer/gmod-arcademachines/blob/master/CONTRIBUTING.md) before submitting your game.**

## Developer information

See `lua/arcademachine_games/test/testgame.lua` for an example minimal game implementation.

For development your script must return a function that returns the game table to prevent errors when running via luadev. Once ready for release, your script must return the game table directly.

You can assign the function to a global variable (e.g. `TESTGAME`) and call `machine:SetGame(TESTGAME)` on the client to test your game.

### Required methods/properties

Your game table must contain the `Name` property.

Your game must implement the following methods:

* `Update()`
* `Draw()`
* `OnStartPlaying(ply)`
* `OnStopPlaying(ply)`

### Optional methods/properties

Your game table can implement the `Description` property. This will be shown when the player looks at the machine before entering. You should tell the player how to play your game here.

Your game table can implement the `Bodygroup` property. This will control the physical appearance of the cabinet. Available bodygroups are:

* `BG_GENERIC_JOYSTICK`
* `BG_GENERIC_TRACKBALL`
* `BG_GENERIC_RECESSED_JOYSTICK`
* `BG_GENERIC_RECESSED_TRACKBALL`
* `BG_DRIVING`

Your game can implement the following methods:

* `Init()`
* `Destroy()`
* `DrawMarquee()`
* `DrawCabinetArt()`
* `OnCoinsInserted(ply, old, new)`
* `OnCoinsLost(ply, old, new)`
* `OnLocalPlayerNearby()`
* `OnLocalPlayerAway()`

### Available globals

* `SCREEN_WIDTH`
* `SCREEN_HEIGHT`
* `MARQUEE_WIDTH`
* `MARQUEE_HEIGHT`
* `CABINET_ART_WIDTH`
* `CABINET_ART_HEIGHT`

### Coins

The machine has its own internal coin count. You can query this count with `COINS:GetCoins()` to determine if the player should be allowed to continue playing or showing the coins remaining.

When the player inserts a coin, if the server implements the `Player:TakeCoins(amount)` method then the arcade machine will attempt to take the amount of coins defined by the networked data table variable `MSCoinCost`. This can be changed on the server per machine with `ent:SetMSCoinCost(amount)` and is shown to the player before they enter the machine.

Your `OnCoinsInserted` method will then be called with the player who inserted coins, the old coin amount and the new amount.

You can take a given number of coins from the machine using `COINS:TakeCoins(amount)`.

When a coin is "used" the method `OnCoinsLost` will be called with the same arguments as `OnCoinsInserted`.

Be aware that because `TakeCoins` sends a netmessage to the server to update the networked variable it takes time for the coin amount to actually change and for `OnCoinsLost` to be called, so do not call `TakeCoins` and then immediately check to see if the player can play - do this check in `OnCoinsLost`.

### The Cabinet

The machine has a marquee that can be drawn to using the `DrawMarquee` method. This method is automatically called when your game is loaded if it exists.

If your marquee requires external images to be loaded before drawing, set the `LateUpdateMarquee` property to `true` on your game table and then call `CABINET:UpdateMarquee()` on the machine after your assets have loaded which will cause `DrawMarquee` to be called once more.

The machine can also have custom artwork (templates available [here](https://github.com/ukgamer/gmod-arcademachines-model/tree/master/matsrc)) that can be drawn to using the `DrawCabinetArt` method. Once any assets you need have loaded and you are ready to draw the cabinet art, call `CABINET:UpdateCabinetArt()`.

**The marquee and cabinet artwork can only be drawn once per game load as they are designed to be static for performance reasons.**

### Helper libraries

Each instance of the same game will receive the same copy of libraries, so that things such as assets
which should be the same between all instances of a game are not reloaded unneccessarily.

`SetGame` also takes an optional second boolean parameter to forcefully reload all libraries for development purposes.

#### Fonts

`FONT:Exists(name)`

Used to check if a font has already been created. Do not use `surface.CreateFont` without first checking if the font has already been created as it is expensive!

#### Images

`IMAGE:LoadFromMaterial(name, key)`

Creates a copy of the given material and registers it with your game. Use this to avoid unnecessary duplicate material loading and to allow materials to use alpha if they do not allow it already.

`IMAGE:LoadFromURL(url, key, callback = nil, noCache = false)`

Used for loading images dynamically from the web as usable `Material`s.

If defined, `callback` will be called on successful load with the below table.

`noCache` can be used during development to bypass the built in caching mechanism.

Access your image with `IMAGE.Images[key]`, which will look like

```lua
{
    status = (0 = STATUS_LOADING, 1 = STATUS_LOADED, 2 = STATUS_ERROR),
    err = "Some error", -- if status == STATUS_ERROR
    mat = Material -- if not yet loaded then error material is used
}
```

#### Sounds

`SOUND:LoadFromURL(url, key, callback = nil)`

If defined, `callback`, is called on successful load with the created `IGModAudioChannel`. This can be used for example to enable looping.

To access your sound use `SOUND.Sounds[key]`, which will look like

```lua
{
    status = (0 = STATUS_QUEUED, 1 = STATUS_LOADING, 2 = STATUS_LOADED, 3 = STATUS_ERROR),
    err = "BASS_SOMEERROR", -- if status == STATUS_ERROR
    sound = IGModAudioChannel -- if status == STATUS_LOADED
}
```

Sounds that are loaded via `LoadFromURL` are queued in order to prevent performance issues when lots of instances of the same game all load their sounds at once. Where possible, try to load your sounds in `OnStartPlaying` and not in `Init`. You should always be checking that the sound you are trying to play `IsValid` before playing it. Subsequent calls to `LoadFromURL` will not do anything if the requested sound has already been queued/loaded.

`SOUND:EmitSound` and `SOUND:StopSound` are also available and have the same signatures the entity methods. `SOUND:Play(name, level, pitch, volume)` is available as an alternative to `sound.Play`.

#### Files

`FILE:LoadFromURL(url, key, callback = nil, noCache = false)`

Used for loading arbitrary files from the web. If defined, `callback` will be called on successful load with the below table.

`noCache` can be used during development to bypass the built in caching mechanism.

Access your file with `FILE.Files[key]`, which will look like

```lua
{
    status = (0 = STATUS_LOADING, 1 = STATUS_LOADED, 2 = STATUS_ERROR),
    err = "Some error", -- if status == STATUS_ERROR
    path = "somepath" -- if status == STATUS_LOADED
}
```

The path is returned so that you can use GMod's usual file methods on it.

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

## Thanks

* Robro - for the model
* Sera - for help with environment wrapping stuff
* Python1320 - for help various things
* Twistalicky - various ideas/suggestions
* Xayr - For letting me ~~steal~~ use his HTTP cache stuff
* All the people who have made/are making games for the machine
* Anyone else I forgot
