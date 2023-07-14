--[[ Utils ]]--
function is_in(t,v)
  for _,val in pairs(t) do
    if(v == val) then return true; end;
  end;
  return false;
end;

--[[ Pattern-based Controls Iterator ]]--
function ctls(pattern)
  local k,v;
  return function(t)
    local function tnext()
      k,v = next(Controls,k)
      return k,v;
    end;
    for k,v in tnext do
      local match = {k:match(pattern)}
      if(#match > 0) then
        table.insert(match, 1, v);
        table.insert(match, k);
        return table.unpack(match);
      end;
    end; 
  end
end;  

--[[ Interlock object creator ]]--
function interlock(pattern, options)

  if(not options) then options = {}; end;

  local current_value;

  local function set(value, prevent_cb)
    current_value = value;
    for c,v,fn in ctls(pattern) do
      c.Boolean = (current_value == v);
    end;
    if(options.callback and not prevent_cb) then options.callback(current_value); end;
  end;

  local function reset()
    if(options.default) then set(options.default, options.no_startup); end;
    for ctl, value in ctls(pattern) do
      if(not current_value) then
        set(value, options.no_startup);
      end;
      ctl.EventHandler = function()
        set(value);
      end;
    end;
  end; reset();

  return setmetatable({},{
    __index = {
      set = function(v) set(v, true); end,
      reset = reset
    },
    __call = function()
      return current_value;
    end
  });

end; 

--[[ Clock object creator]]--
function clock(ctl, format)
  if(not _G._locimation_lib_data.ClockTimer) then
    _G._locimation_lib_data.ClockTimer = {};
  end
  _G._locimation_lib_data.ClockTimer[ctl] = Timer.New();
  _G._locimation_lib_data.ClockTimer[ctl].EventHandler = function()
    ctl.String = os.date(format);
  end;
  _G._locimation_lib_data.ClockTimer[ctl]:Start(0.2);
end;

--[[ Press + Hold object creator ]]
function presshold(ctl, options)
  options = options or {};
  if(not options.threshold) then options.threshold = 2; end;

  -- Initialise globals
  if(not _G._locimation_lib_data.PressHold) then

    _G._locimation_lib_data.PressHold = {
      Timer = Timer.New(),
      State = {},
      Press = {},
      Hold = {}
    }

    _G._locimation_lib_data.PressHold.Timer.EventHandler = function()
      local now = Timer.Now(); 
      for ctl,time in pairs(_G._locimation_lib_data.PressHold.State) do
        if(time and now > time) then
          ctl.Boolean = false;
          if(_G._locimation_lib_data.PressHold.Hold[ctl]) then
            _G._locimation_lib_data.PressHold.Hold[ctl](ctl);
          end;
          _G._locimation_lib_data.PressHold.State[ctl] = nil;
        end;
      end;
    end;

    _G._locimation_lib_data.PressHold.Timer:Start(0.2);

  end

  -- Event Handlers
  if(options.Hold) then
    if(type(options.Hold) ~= 'function') then error('PressHold.Hold expects a function.'); end;
    _G._locimation_lib_data.PressHold.Hold[ctl] = options.Hold;
  end;
  if(options.Press) then
    if(type(options.Press) ~= 'function') then error('PressHold.Press expects a function.'); end;
    _G._locimation_lib_data.PressHold.Press[ctl] = options.Press;
  end;

  ctl.EventHandler = function()
    if(ctl.Boolean) then
      _G._locimation_lib_data.PressHold.State[ctl] = Timer.Now() + options.threshold;
    else
      if(_G._locimation_lib_data.PressHold.Press[ctl]) then
        _G._locimation_lib_data.PressHold.Press[ctl](ctl);
      end;
      _G._locimation_lib_data.PressHold.State[ctl] = nil; 
    end;
  end;

  return setmetatable(options, {
    __index = function() return nil; end,
    __newindex = function(t,k,v)
      if(k == 'Threshold') then
        if(type(v) ~= 'number') then error('PressHold.Threshold expects a number.'); end;
        rawset(t, 'threshold', v);
      elseif(k == 'Hold') then
        if(type(v) ~= 'function') then error('PressHold.Hold expects a function.'); end;
        _G._locimation_lib_data.PressHold.Hold[ctl] = v;
      elseif(k == 'Press') then
        if(type(v) ~= 'function') then error('PressHold.Press expects a function.'); end;
        _G._locimation_lib_data.PressHold.Press[ctl] = v;
      else
        error('Property "' .. k .. '" does not exist on PressHold.');
      end
    end
  });

end;

--[[ Volume control object creator ]]--
function volume(ctl, options)

  options = options or {};
  if(not options.RepeatDelay) then options.RepeatDelay = 0.35; end;
  if(not options.RepeatInterval) then options.RepeatInterval = 0.1; end;
  if(not options.Increment) then options.Increment = 0.05; end;
  if(not options.Min) then options.Min = 0; end;
  if(not options.Max) then options.Max = 1; end;

  if(options.Prefix and not options.Up) then
    options.Up = Controls[options.Prefix .. 'Up'];
  end;

  if(options.Prefix and not options.Down) then
    options.Down = Controls[options.Prefix .. 'Down'];
  end;

  if(type(ctl) ~= 'userdata') then
    error('bad argument #1 to volume (expected control, got ' .. type(options.Up)..')');
  end;

  for _,option in pairs({'RepeatDelay', 'RepeatInterval', 'Increment', 'Min', 'Max'}) do
    if(type(options[option]) ~= 'number') then
      error('Volume.'..option..' expects number, got ' .. type(options[option]));
    end;
  end;

  if(options.Up and type(options.Up) ~= 'userdata') then
    error('Volume.Up expects control, got ' .. type(options.Up));
  end;

  if(options.Down and type(options.Down) ~= 'userdata') then
    error('Volume.Down expects control, got ' .. type(options.Down));
  end;

  if(options.Change and type(options.Change) ~= 'function') then
    error('Volume.Change expects function, got ' .. type(options.Change));
  end;

  if(not _G._locimation_lib_data.Volume) then
    _G._locimation_lib_data.Volume = {};
  end;

  local function nudge()

    local delta = 0;
    if(options.Up) then delta = delta + options.Up.Value; end;
    if(options.Down) then delta = delta - options.Down.Value; end;
    delta = delta * options.Increment;

    local newPosition = ctl.Position + delta;
    if(options.Max and newPosition > options.Max) then newPosition = options.Max; end;
    if(options.Min and newPosition < options.Min) then newPosition = options.Min; end;

    if(ctl.Position ~= newPosition) then
      ctl.Position = newPosition;
      if(options.Change) then options.Change(ctl); end;
    end;

  end;

  _G._locimation_lib_data.Volume[ctl] = Timer.New();
  _G._locimation_lib_data.Volume[ctl].EventHandler = function()
    _G._locimation_lib_data.Volume[ctl]:Stop();
    _G._locimation_lib_data.Volume[ctl]:Start(options.RepeatInterval);
    nudge();
  end;

  local function upDownHandler(c)
    if(c.Boolean) then
      nudge();
      _G._locimation_lib_data.Volume[ctl]:Start(options.RepeatDelay);
    else
      _G._locimation_lib_data.Volume[ctl]:Stop();
    end;
  end;

  if(options.Up) then options.Up.EventHandler = upDownHandler; end;
  if(options.Down) then options.Down.EventHandler = upDownHandler; end;

  if(options.Change) then options.Change(ctl); end;

end;

_G._locimation_lib_data = {};