# locimation-lib
*Helper functions for Q-SYS Scripts*

Install as a [design resource](https://q-syshelp.qsc.com/#Control_Scripting/External_Lua_Modules.htm).


## Utilities

### is_in

Returns true if the given value exists in the given table. Otherwise, false.

```lua
if(is_in(my_table, 42)) then ... end
```

### find_in

Returns the index / key of the given value if it exists in the given table. Otherwise, nil.

```lua
local key = find_in(my_table, 42)
```

### deep_copy

Creates a deep copy of a table by recursively copying all values, such that changes to either table do not affect the other.

```lua
local my_copy = deep_copy(existing_table)
```

## Controls API Helpers

### ctls

Provides a pattern-based iterator for controls - helpful for UCI scripts.

For example, to make an event handler generic across a set of controls:

`Control-1`, `Control-2`, `Control-3`, `Control-4`

```lua
for ctl, number in ctls('^Control%-(%d+)$') do
  ctl.EventHandler = function()
    print('Control number ' .. number .. ' pressed.');
  end;
end;
```

Multiple matches can also be returned:

`In1-Out1`, `In1-Out2`, `In2-Out1`, `In2-Out2`

```lua
for ctl, input, output in ctls('^In(%d+)%-Out(%d+)$') do
  ctl.EventHandler = function()
    print('Routing input ' .. input .. ' to output ' .. output);
  end;
end;
```

The full control name is always returned as the final value, after any captures:

```lua
for ctl, input, output, name in ctls('^In(%d+)%-Out(%d+)$') do
  print('Matched control: ' .. name);
end;
```

Note that calling ctls() can become expensive in UCI's with a large number of controls, in which case it is recommended to cache the results, or to use the `Ctls` table.

## Ctls

The `Ctls` table is a nested table of controls, organised by parts of the control name separated by underscores.

It must be built by calling `Ctls()` once, near the top of your script:

```lua
Ctls();
```

For example, given the following controls:

- `Control_1`
- `Control_2`
- `Control_3`
- `Button_One`
- `Button_Two`

The `Ctls` table would look like this:

```lua
{
  Control = {
    Controls.Control_1,
    Controls.Control_2,
    Controls.Control_3
  },
  Button = {
    One = Controls.Button_One,
    Two = Controls.Button_Two
  }
}

```

(Note that numeric keys are automatically converted from strings to numbers.)

## interlock

Creates an `Interlock` object based on a control pattern:

```lua
MyInterlock = interlock('^Control%-(%d+)$')
```

or, using the `Ctls` table:

```lua
MyInterlock = interlock(Ctls.Sources)
```

either of which can have optional configuration:

```lua
MyInterlock = interlock('^Control%-(%d+)$', {
  default = '2',
  callback = function(value) print(value) end,
  no_startup = true
})
```

- `default` determines which control will be set to true on startup
- `callback` will be called whenever the value changes, and
- `no_startup` prevents the callback from being run when the default value is set.

The interlock object then presents an API:

```lua
-- Get the current value of the interlock
print('Current value is: ' .. MyInterlock())

-- Set the current value of the interlock
MyInterlock.set('2');

-- or, without triggering the callback
MyInterlock.set('2', true);

-- Reset the interlock to its default value
MyInterlock.reset();

-- or, without triggering the callback
MyInterlock.reset(true);
```

## clock

Turns a given control into a clock display with given format.

Example:
```lua
clock(Controls.MyClock, '%H:%M %p');
```

Optional third parameter to remove leading zeros from the hour:
```lua
clock(Controls.MyClock, '%H:%M %p', true);
```

If the control has a `Legend` property (e.g. a button), it is updated with the time as well.

## init

Allows code execution to be delayed until the end of the script, whilst allowing behaviour to remain in context.

To register a function to be called later:
```lua
init(function()
  print('This will be printed later')
end);
```

Then at the end of the script, run all the functions fed to `init()` by calling `init()` with no parameters.
```lua
init() 
```

The `interlock()` object also supports its callback's first run being via init():
```lua
interlock('^MyButtons_(%d)$', {
  callback = print,
  delayed_init_callback = true
})
```


## presshold

Creates a "Press & Hold" object from a momentary button.

All parameters are optional and can be changed at runtime. `Threshold` is the hold time in seconds, and defaults to 2.

Example:
```lua
-- Initial configuration
presshold(Controls.MyMomentaryButton, {
  Threshold = 2,
  Press = function() print('Short press!'); end,
  Hold = function() print('Long press!'); end
});

-- Dynamic configuration
MyPressHold = presshold(Controls.MomentaryButton);
MyPressHold.Threshold = 4;
MyPressHold.Press = function() print('Press!') end;
MyPressHold.Hold = function() print('Hold!'); end;
```


## set_selector

Q-SYS "Selector" components cannot be set directly to a text value in the usual form:
```lua
Component.New('My Selector').selector.String = "Selection 1";
```
because the "selector" control has embedded JSON data that enables the selector component to function.

This library provides a helper function to set the value of a selector control to a specified text value (by searching through the list of label texts) as follows:

```lua
set_selector(
  Component.New('My Selector').selector,
  "Selection 1"
);
```

## fn()

A helper function to create a function that calls another function with predefined arguments.

Example:
```lua
function my_function(a, b, c)
  print(a, b, c)
end

Controls.MyButton.EventHandler = fn(my_function, 1, 2, 3)
```

## link(control, control, ..., optional_property)

Links the values of two or more controls, so that changing any one of them updates all the others. If the last argument is a string, it is used as the property to link.

Note that at the time of linking, all controls are set to the state of the *first* control.

Example:
```lua
link(Controls.MySlider, Controls.MyGauge) -- links via String by default
link(Controls.MySlider, Controls.MyGauge, 'Value') -- links via Value (numeric)
link(Controls.MySlider, Controls.MyGauge, 'Boolean') -- links via Boolean
link(Controls.MySlider, Controls.MyGauge, 'Position') -- links via Position

-- any number of controls can be linked
link(Controls.FaderA, Controls.FaderB, Controls.FaderC, 'Position')
```

The returned object behaves like a control: reading a property (`.String`, `.Value`, `.Boolean`, `.Position`, etc.) reads from the *first* control, while writing a property sets it on *all* linked controls.

```lua
MyLink = link(Controls.MySlider, Controls.MyGauge, 'Position');

MyLink.Position = 0.5; -- set all linked controls
print(MyLink.Position); -- read the current value (from the first control)

-- any property can be written to all linked controls
MyLink.Color = 'red';
```

Assigning `.EventHandler` on the link does not replace the controls' own handlers (which keep the link in sync); instead, it is called with the link object after each sync:

```lua
MyLink.EventHandler = function(link)
  print('Link changed:', link.Position);
end
```

## volume

Creates a volume control object, driving a target control from momentary "up" and "down" buttons with press-and-hold repeat.

```lua
volume(Controls.MyFader, {
  Up = Controls.VolumeUp,
  Down = Controls.VolumeDown
});
```

Instead of passing `Up` and `Down` directly, they can be looked up by name using `Prefix` and/or `Suffix`. For example, this resolves the buttons `Controls.Volume_Up_1` and `Controls.Volume_Down_1`:

```lua
volume(Controls.MyFader, {
  Prefix = 'Volume_',
  Suffix = '_1'
});
```

The first argument may be:

- a **control** — its `Position` is adjusted directly;
- a **function returning a control** — useful when the target control may change at runtime, e.g. `function() return Controls[current_zone]; end`;
- a **string** — treated as a key in the global `K` store provided by the *locimation-k* library, which synchronises control states across Q-SYS cores. The position is read and written via `K.get` / `K.set`.

Options (all optional unless noted):

- `Up`, `Down` — the momentary button controls (required, unless resolved via `Prefix`/`Suffix`)
- `Prefix`, `Suffix` — strings used to look up `Controls[Prefix .. 'Up' .. Suffix]` and `Controls[Prefix .. 'Down' .. Suffix]`
- `Increment` — position change per step (default `0.05`)
- `RepeatDelay` — seconds a button must be held before repeating begins (default `0.35`)
- `RepeatInterval` — seconds between repeats while held (default `0.1`)
- `Min`, `Max` — position limits (defaults `0` and `1`)
- `Change` — callback invoked whenever the volume changes; it receives the target control (or, for the `K` form, the new position). It is also attached as the target's event handler and called once at setup.

The returned object provides `set` and `update` methods:

```lua
MyVolume = volume(Controls.MyFader, {
  Up = Controls.VolumeUp,
  Down = Controls.VolumeDown,
  Change = function(ctl) print('Volume is now ' .. ctl.Position); end
});

MyVolume.set(0.75); -- set the position directly (triggers Change)
MyVolume.update(); -- re-run the Change callback with the current state
```

## navigator

Creates a page navigation object for a UCI, treating a set of layers as mutually-exclusive "pages" on a given UCI page.

```lua
Nav = navigator('Main', { 'Home', 'Audio', 'Video', 'Settings' });
Nav.go('Home');
```

Navigating with `go` shows the target layer, hides the other page layers, and runs any registered hooks. If a layer in the list does not exist on the page, a warning is printed (see `warn` below).

### Methods

**`go(page)`** — navigate to the given page (layer name).

**`goFn(page)`** — returns a function that navigates to the page; convenient for event handlers:

```lua
Controls.HomeButton.EventHandler = Nav.goFn('Home');
```

**`back()`** — navigate to the previous page in the history. History tracking must first be enabled with `history_from`, otherwise this raises an error.

**`history_from(page)`** — enables history tracking. Call this once, typically with your home page:

```lua
Nav.history_from('Home');
```

**`history_skip(page)`** — marks a page to be skipped over when navigating back through the history (e.g. transient pages like a PIN entry screen):

```lua
Nav.history_skip('PinEntry');
```

**`transition(layer_name, transition)`** — sets the default transition used when showing or hiding the given layer (e.g. `'fade'`, `'left'`, `'right'`, `'top'`, `'bottom'`, `'none'`):

```lua
Nav.transition('Settings', 'fade');
```

**`depend(layer_name, parent_layers)`** — makes a layer visible only whilst the current page is one of the given parent pages, e.g. a shared toolbar:

```lua
Nav.depend('Toolbar', { 'Audio', 'Video' });
```

**`layer(layer_name, state, transition)`** — directly shows or hides a layer on the page, using the layer's default transition if none is given.

**`hook(fn)`** — registers a function to be called with the page name on every navigation:

```lua
Nav.hook(function(page) print('Navigated to ' .. page); end);
```

**`on(page, fn)`** — registers a function to be called whenever the given page is navigated to:

```lua
Nav.on('Settings', function() print('Settings opened'); end);
```

**`get()`** — returns the current page name.

**`warn(enabled)`** — enables or disables the "layer not found" warnings (enabled by default).

## popupper

Creates a popup management object for a UCI — like `navigator`, but for a set of popup layers where at most one is visible and *none visible* is the normal state.

```lua
Popups = popupper('Main', { 'HelpPopup', 'ConfirmPopup' });
```

All popup layers are hidden when the popupper is created.

### Methods

**`popup(layer_name)`** — shows the given popup (hiding any other). Raises an error if the layer was not in the list.

**`popupFn(layer_name)`** — returns a function that shows the popup; convenient for event handlers:

```lua
Controls.HelpButton.EventHandler = Popups.popupFn('HelpPopup');
```

**`close()`** — hides all popups.

**`toggleFn(layer_name)`** — returns an event handler for a toggle button that shows the popup when pressed on, and closes it when pressed off:

```lua
Controls.HelpButton.EventHandler = Popups.toggleFn('HelpPopup');
```

**`hook(fn)`**, **`on(popup, fn)`**, **`layer(...)`**, **`depend(...)`**, **`get()`** — as per `navigator`.