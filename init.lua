---@diagnostic disable: lowercase-global
--[[ Utils ]]--
function find_in(t,v)
  for k,val in pairs(t) do
    if(v == val) then return k; end;
  end;
  return nil;
end;

function is_in(t,v)
  return find_in(t,v) ~= nil;
end;

function deep_copy(orig, copies)
  copies = copies or {}
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
      if copies[orig] then
          copy = copies[orig]
      else
          copy = {}
          copies[orig] = copy
          for orig_key, orig_value in next, orig, nil do
              copy[deep_copy(orig_key, copies)] = deep_copy(orig_value, copies)
          end
          setmetatable(copy, deep_copy(getmetatable(orig), copies))
      end
  else -- number, string, boolean, etc
      copy = orig
  end
  return copy
end

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

--[[ Selector setter ]]--
function set_selector(control, text)
  for _, json_string in ipairs(control.Choices) do
    local ok, data = pcall(require('json').decode, json_string);
    if(ok and data.Text == text) then
      control.String = json_string;
    end;
  end;
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
    if(options.callback and not prevent_cb) then
      options.callback(current_value);
    end;
  end;

  local function reset(prevent_cb)
    if(options.default) then set(options.default, prevent_cb); end;
    for ctl, value in ctls(pattern) do
      if(not current_value) then
        set(value, prevent_cb);
      end;
      ctl.EventHandler = function()
        set(value);
      end;
    end;
  end;
  
  reset(true); -- prevent auto callback
  if(options.delayed_init_callback) then
    init(function() options.callback(current_value) end);
  elseif(not options.no_startup) then
    options.callback(current_value);
  end; 

  return setmetatable({},{
    __index = {
      set = function(v) set(v); end,
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
    if(ctl.Legend) then ctl.Legend = os.date(format); end;
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

--[[ Initialisation helper ]]--
function init(fn)
  _G._locimation_lib_data.init_functions
    = _G._locimation_lib_data.init_functions or {};
  
  if(fn) then
    table.insert(_G._locimation_lib_data.init_functions, fn);
  else
    for _,fn in ipairs(_G._locimation_lib_data.init_functions) do
      fn();
    end
  end;

end;

--[[ Volume control object creator ]]--
function volume(ctl, options)

  options = options or {};
  if(not options.RepeatDelay) then options.RepeatDelay = 0.35; end;
  if(not options.RepeatInterval) then options.RepeatInterval = 0.1; end;
  if(not options.Increment) then options.Increment = 0.05; end;
  if(not options.Min) then options.Min = 0; end;
  if(not options.Max) then options.Max = 1; end;

  if((options.Prefix or options.Suffix) and not options.Up) then
    local name = (options.Prefix or '') .. 'Up' .. (options.Suffix or '');
    options.Up = Controls[name];
    if(not options.Up) then error('Missing volume up control: ' .. name); end;
  end;

  if((options.Prefix or options.Suffix) and not options.Down) then
    local name = (options.Prefix or '') .. 'Down' .. (options.Suffix or '');
    options.Down = Controls[name];
    if(not options.Down) then error('Missing volume down control: ' .. name); end;
  end;

  if(type(ctl) ~= 'userdata' and type(ctl) ~= 'control') then
    error('bad argument #1 to volume (expected control or userdata, got ' .. type(ctl)..')');
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

  options.Up.EventHandler = upDownHandler;
  options.Down.EventHandler = upDownHandler;

  if(options.Change) then
    ctl.EventHandler = options.Change;
    options.Change(ctl);
  end;

  return {
    set = function(position)
      ctl.Position = position;
      if(options.Change) then options.Change(ctl); end;
    end;
  }

end;

-- [[ fn() helper ]] --
function fn(fn, ...)
  local args = {...};
  return function()
    fn(table.unpack(args));
  end;
end;

_G._locimation_lib_data = {};