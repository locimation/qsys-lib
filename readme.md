# locimation-lib
*Helper functions for Q-SYS Scripts*

Install as a [design resource](https://q-syshelp.qsc.com/#Control_Scripting/External_Lua_Modules.htm).


## Utilities

### is_in

Returns true if the given value exists in the given table. Otherwise, false.

```lua
if(is_in(my_table, 42)) then ... end
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

## interlock

Creates an `Interlock` object based on a control pattern:

```lua
MyInterlock = interlock('^Control%-(%d+)$')
```

with optional configuration:

```lua
MyInterlock = interlock('^Control%-(%d+)$', {
  default = '2',
  callback = function(value) print(value) end,
  nostartup = true
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

-- Reset the interlock to its default value
MyInterlock.reset();
```

## clock

Turns a given control into a clock display with given format.

Example:
```lua
clock(Controls.MyClock, '%H:%I %p');
```