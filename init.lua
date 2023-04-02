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
  if(not _G.ClockTimer) then
    _G.ClockTimer = {};
  end
  _G.ClockTimer[ctl] = Timer.New();
  _G.ClockTimer[ctl].EventHandler = function()
    ctl.String = os.time(format);
  end;
  _G.ClockTimer:Start(0.2);
end;