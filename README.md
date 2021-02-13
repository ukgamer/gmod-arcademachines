# Arcade Cabinets

**Please read [CONTRIBUTING](https://github.com/ukgamer/gmod-arcademachines/blob/master/CONTRIBUTING.md) before submitting your game.**

## Developer information

See `lua/arcade_cabinet_games/test/testgame.lua` for an example minimal game implementation.

For development your script must return a function that returns the game table to prevent errors when running via luadev. Once ready for release, your script must return the game table directly.

You can assign the function to a global variable (e.g. `TESTGAME`) and call `cabinet:SetGame(TESTGAME)` on the client to test your game.

### Required methods/properties

Your game table must contain the `Name` property.

Your game must implement the following methods:

* `Update()`
* `Draw()`
* `OnStartPlaying(ply)`
* `OnStopPlaying(ply)`

### Optional methods/properties

Your game table can implement following properties:
* `Author` - Your name.
* `Description` - Tell the player how to play your game here.
* `Bodygroup` - This will control the physical appearance of the cabinet. Available bodygroups are:
    * `BG_GENERIC_JOYSTICK`
    * `BG_GENERIC_TRACKBALL`
    * `BG_GENERIC_RECESSED_JOYSTICK`
    * `BG_GENERIC_RECESSED_TRACKBALL`
    * `BG_DRIVING`

Your game can implement the following methods:

* `Init()`
* `Destroy()`
* `DrawMarquee()`
* `OnCoinsInserted(ply, old, new)`
* `OnCoinsLost(ply, old, new)`
* `OnLocalPlayerNearby()`
* `OnLocalPlayerAway()`

### Available globals

* `SCREEN_WIDTH`
* `SCREEN_HEIGHT`
* `MARQUEE_WIDTH`
* `MARQUEE_HEIGHT`

### Coins

The cabinet has its own internal coin count. You can query this count in your game with `COINS:GetCoins()` to determine if the player should be allowed to continue playing or for showing the coins remaining.

When the player attempts to insert a coin, the clientside hook `ArcadeCabinetCanPlayerAfford` is called with the cost defined by the networked data table variable `Cost`. If this hook returns `false` an error message is shown to the player. If it returns anything else, the serverside hook `ArcadeCabinetInsertCoin` is then called with the player and cost. If this hook returns `false` the coin will not be inserted.

Your game's `OnCoinsInserted` method will then be called with the player who inserted coins, the old coin amount and the new amount.

The cost can be changed on the server per cabinet with `ent:SetCost(amount)` and is shown to the player before they enter the cabinet.

You can take a given number of coins from the cabinet using `COINS:TakeCoins(amount)`.

When a coin is "used" the method `OnCoinsLost` will be called with the same arguments as `OnCoinsInserted`.

Be aware that because `TakeCoins` sends a netmessage to the server to update the networked variable it takes time for the coin amount to actually change and for `OnCoinsLost` to be called, so do not call `TakeCoins` and then immediately check to see if the player can play - do this check in `OnCoinsLost`.

### The Cabinet

The cabinet has a marquee that can be drawn to using the `DrawMarquee` method. This method is automatically called when your game is loaded if it exists.

If your marquee requires external images to be loaded before drawing, set the `LateUpdateMarquee` property to `true` on your game table and then call `CABINET:UpdateMarquee()` on the cabinet after your assets have loaded which will cause `DrawMarquee` to be called once more.

The cabinet can also have custom artwork (templates available [here](https://github.com/ukgamer/gmod-arcademachines-model/tree/master/matsrc)) that can be specified with the `CabinetArtURL` property on your game table.

**The marquee can only be drawn once per game load as it is designed to be static for performance reasons.**

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

`IMAGE:LoadFromURL(url, key, callback = nil, noCache = false, materialParams = nil)`

Used for loading images dynamically from the web as usable `Material`s.

If defined, `callback` will be called on successful load with the below table.

`noCache` can be used during development to bypass the built in caching mechanism.

`materialParams` can be passed to the underlying `Material` function - see [the GMod wiki](https://wiki.facepunch.com/gmod/Material_Parameters).

Access your image with `IMAGE.Images[key]`, which will look like

```lua
{
    status = (0 = STATUS_LOADING, 1 = STATUS_LOADED, 2 = STATUS_ERROR),
    err = "Some error", -- if status == STATUS_ERROR
    mat = Material -- if not yet loaded then error material is used
}
```

#### Sounds

The sound library is mostly a wrapper to GMod's sound functions in order to handle positioning/playing of sounds and cleaning up when games are unloaded.

`SOUND:LoadFromURL(url, key, callback = nil)`

If defined, `callback`, is called on successful load with the created `IGModAudioChannel`. This can be used for example to enable looping.

To access your sound use `SOUND.Sounds[key]`, which will look like

```lua
{
    status = (0 = STATUS_LOADING, 1 = STATUS_LOADED, 2 = STATUS_ERROR),
    err = "BASS_SOMEERROR", -- if status == STATUS_ERROR
    sound = IGModAudioChannel -- if status == STATUS_LOADED
}
```

Where possible, try to load your sounds in `OnStartPlaying` and not in `Init` (unless you need sounds for the attract mode). You should always be checking that the sound you are trying to play `IsValid` before playing it. Subsequent calls to `LoadFromURL` will not do anything if the requested sound has already been loaded.

If your game makes sounds in its attract mode, ensure you check the boolean result of `SOUND:ShouldPlaySound` to know if you should actually play the sound (in case the player has disabled sounds playing outside of their current cabinet).

`SOUND:EmitSound` and `SOUND:StopSound` are also available and have the same signatures as the entity methods. `SOUND:Play(name, level, pitch, volume)` is available as an alternative to `sound.Play`.

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

* TYPE_BOX
* TYPE_CIRCLE
* TYPE_POLY

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
        type = COLLISION.TYPE_BOX, -- see types above
        width = 5, -- if TYPE_BOX
        height = 5, -- if TYPE_BOX
        radius = 5, -- if TYPE_CIRCLE
        vertices = { -- if TYPE_POLY
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
* All the people who have made/are making games for the cabinet
* Anyone else I forgot
