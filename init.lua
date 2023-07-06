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
  if(options.Hold) then
    if(type(options.Hold) ~= 'function') then error('PressHold.Hold expects a function.'); end;
    _G._locimation_lib_data.PressHold.Hold[ctl] = options.Hold;
  end;
  if(options.Press) then
    if(type(options.Press) ~= 'function') then error('PressHold.Press expects a function.'); end;
    _G._locimation_lib_data.PressHold.Press[ctl] = options.Press;
  end;

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

_G._locimation_lib_data = {};