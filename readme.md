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

Returns the index / key of the given value if it exists in the given table. Otherwise, false.

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

Note that calling ctls() can become expensive in UCI's with a large number of controls, in which case it is recommended to cache the results, or to use the `Ctls` table.

## Ctls

The `Ctls` table is a nested table of controls, organised by parts of the control name separated by underscores.

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
- `nostartup` prevents the callback from being run when the default value is set.

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

All parameters are optional and can be changed at runtime.

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

## link(control_a, control_b, optional_property)

Links the value of `control_a` to `control_b`. If `optional_property` is provided, it will be used as the property to link.

Note that control_a will get set to the state of control_b at the time of linking.

Example:
```lua
link(Controls.MySlider, Controls.MyGauge) -- links via String by default
link(Controls.MySlider, Controls.MyGauge, 'Value') -- links via Value (numeric)
link(Controls.MySlider, Controls.MyGauge, 'Boolean') -- links via Boolean
link(Controls.MySlider, Controls.MyGauge, 'Position') -- links via Position
```