---@meta
-- LuaCATS stubs for the rex global, from https://www.superlogical.com/rex/docs/reference/lua
-- and reference/events. view shapes from `rex api describe session.view`

---@class rex.Context
---@field session_id string
---@field block_id? string
---@field client_id? string
---@field origin? string "timer" for rex.after/rex.every
---@field server? string

---@class rex.KeyEvent
---@field keybinding string
---@field prefix? string[] keys before it, for a sequence

---@class rex.Binding
---@field key string
---@field mode? string
---@field action? string
---@field fn? fun(ctx: rex.Context, ev: rex.KeyEvent): boolean?
---@field args? table
---@field source string e.g. `keys.lua:3`

---@class rex.Mode
---@field name string
---@field exclusive boolean
---@field source string

---@alias rex.ArgType "string"|"number"|"integer"|"boolean"|"object"|"array"|"any"|"string?"|"number?"|"integer?"|"boolean?"|"object?"|"array?"|"any?"

---@class rex.ActionSpec
---@field name string lowercase letters, digits and underscores
---@field title string shown in the command palette
---@field run fun(ctx: rex.Context, args: table): any
---@field description? string
---@field category? string defaults to `Actions`
---@field keywords? string
---@field args? table<string, rex.ArgType>|table JSON Schema or a name → type map
---@field repeats? boolean run again while the key is held

---@class rex.HostSpec
---@field label string
---@field endpoints? string[] tried in order
---@field endpoint? string
---@field id? string
---@field icon? string

---@alias rex.Rect number[] { x, y, w, h } fractions of the window

---@class rex.ViewBlock
---@field block_id string
---@field creator_name string
---@field flavor string
---@field host_id string
---@field label string
---@field owner? string

---@class rex.Split
---@field split_id string
---@field direction "horizontal"|"vertical"
---@field ratio number share `before` gets
---@field before rex.LayoutNode left or top
---@field after rex.LayoutNode right or bottom

---@class rex.LayoutNode
---@field rect rex.Rect
---@field block_id? string set only when split isn't
---@field split? rex.Split

---@class rex.Layer
---@field layer_id string
---@field kind "tiled"|"floating"
---@field bounds rex.Rect
---@field blocks rex.ViewBlock[]
---@field layout? rex.LayoutNode nil when the layer is empty
---@field state? "minimized"

---@class rex.Window
---@field window_id string
---@field label string
---@field focused_block_id? string
---@field zoomed_block_id? string
---@field layers rex.Layer[] back to front; the first is the tiled layer

---@class rex.View
---@field session_id string
---@field label string
---@field revision integer
---@field active_window_id? string
---@field windows rex.Window[]

---@class rex.LayoutSpec

---@alias rex.SessionMethod fun(args?: table): table?, string?

---@class rex.Session
---@field view fun(args?: { session_id?: string }): rex.View?, string?
---@field list_blocks rex.SessionMethod
---@field list_clients rex.SessionMethod
---@field describe_block rex.SessionMethod
---@field new_window rex.SessionMethod
---@field new_split rex.SessionMethod
---@field new_block rex.SessionMethod
---@field new_layer rex.SessionMethod
---@field close_window rex.SessionMethod
---@field close_layer rex.SessionMethod
---@field move_block rex.SessionMethod
---@field swap_blocks rex.SessionMethod
---@field detach_block rex.SessionMethod
---@field float_block rex.SessionMethod
---@field zoom_block rex.SessionMethod
---@field resize_pane rex.SessionMethod
---@field resize_layer rex.SessionMethod
---@field raise_layer rex.SessionMethod
---@field lower_layer rex.SessionMethod
---@field move_window rex.SessionMethod
---@field focus_block rex.SessionMethod
---@field focus_window rex.SessionMethod
---@field focus_direction rex.SessionMethod
---@field focus_next_pane rex.SessionMethod
---@field focus_previous_pane rex.SessionMethod
---@field focus_next_window rex.SessionMethod
---@field focus_previous_window rex.SessionMethod
---@field set_label rex.SessionMethod
---@field set_window_label rex.SessionMethod
---@field set_block_label rex.SessionMethod
---@field attach rex.SessionMethod
---@field detach rex.SessionMethod
---@field help rex.SessionMethod
---@field [string] rex.SessionMethod

---@alias rex.TerminalMethod "format"|"process"|"pwd"|"title"|"size"|"write"|"reset"|"resize"|"set_theme"|"program_status"|"list_dir"

---@class rex.Block
local Block = {}

-- `block_id` defaults to the current block
---@param creator string|"com.superlogical.terminal"
---@param method rex.TerminalMethod|string
---@param args? table
---@return table?, string?
function Block.call(creator, method, args) end

---@class rex.Server
---@field session rex.Session
---@field block rex.Block
local Server = {}

---@param method string
---@param args? table
---@return table?, string?
function Server.call(method, args) end

---@class rex.ExecOpts
---@field cwd? string
---@field env? table<string, string|false> false removes a variable
---@field clear_env? boolean
---@field stdin? string
---@field timeout? number seconds until SIGTERM, then SIGKILL 2s later
---@field stdout? false
---@field stderr? false
---@field text? boolean

---@class rex.ExecStartOpts: rex.ExecOpts
---@field stdin? string|boolean true keeps stdin open for h:write
---@field stdout? false|fun(chunk: string)
---@field stderr? false|fun(chunk: string)
---@field detach? boolean outlive the action, handler or script that started it

---@class rex.ExecResult
---@field code integer -1 when a signal ended it
---@field signal? string
---@field stdout string
---@field stderr string
---@field timed_out boolean
---@field ok boolean

---@class rex.Process
---@field pid integer
local Process = {}

---@param seconds? number
---@return rex.ExecResult?, string?
function Process:wait(seconds) end

---@param data string
---@return true?, string?
function Process:write(data) end

function Process:close_stdin() end

---@param signal? string|integer defaults to SIGTERM
function Process:kill(signal) end

---@return boolean
function Process:running() end

---@class rex.Timer
local Timer = {}

function Timer:cancel() end

---@return boolean
function Timer:active() end

---@class rex.Exec
---@overload fun(argv: string[], opts?: rex.ExecOpts): rex.ExecResult?, string?
local Exec = {}

---@param argv string[]
---@param opts? rex.ExecStartOpts
---@return rex.Process?, string?
function Exec.start(argv, opts) end

---@class rex.Event
---@field type string `block_event` for every terminal event
---@field session_id? string
---@field payload table
---@field block_id? string block events only
---@field creator_name? string block events only
---@field name? string block events only, without the creator
---@field [string] any

---@alias rex.EventName
---| "window_created" | "window_closed" | "window_label_changed" | "active_window_changed"
---| "block_created" | "block_closed" | "block_event"
---| "session_label_changed" | "session_view_changed"
---| "client_connected" | "client_disconnected" | "client_connection_changed" | "creator_changed"
---| "terminal.child_exited" | "terminal.pwd_changed" | "terminal.title_changed" | "terminal.bell"
---| "terminal.process_changed" | "terminal.desktop_notification" | "terminal.progress_report"
---| "terminal.clipboard_written" | "terminal.program_status_changed" | "terminal.program_status_removed"
---| "session_created" | "session_destroyed" | "client_joined" | "client_left" | "client_changed"
---| "keymap_changed" | "hosts_changed" | "tailscale_status_changed"

---@class rex
---@field session rex.Session
---@field block rex.Block
---@field exec rex.Exec
---@field args table scripts only
---@field session_id string scripts only
---@field block_id? string scripts only
rex = {}

-- key bindings

---@param key string a key, a `>` sequence, or either prefixed with `mode/`
---@param action string
---@param args? table
---@overload fun(key: string, fn: fun(ctx: rex.Context, ev: rex.KeyEvent): boolean?)
function rex.bind(key, action, args) end

---@param key string
---@param target? string|function
---@return integer removed
---@overload fun(spec: { mode: string })
---@overload fun(binding: rex.Binding): integer
function rex.unbind(key, target) end

---@param name string
---@param options? { exclusive?: boolean }
function rex.mode(name, options) end

---@param filter? { key?: string, mode?: string, action?: string }
---@return rex.Binding[]
function rex.bindings(filter) end

---@return rex.Mode[]
function rex.modes() end

-- actions

---@param spec rex.ActionSpec
function rex.action(spec) end

---@param name string
---@param args? table
---@return any, string?
function rex.invoke(name, args) end

rex.client = {}

-- a client action such as `pane.zoom`. raises when there is no client
---@param name string
---@param args? table
function rex.client.queue(name, args) end

-- calling rex

---@param method string full name, e.g. `session.list`
---@param args? table
---@return table?, string?
function rex.call(method, args) end

rex.layout = {}

---@param spec { flavor: string|"com.superlogical.terminal.shell", label?: string, options?: { command?: string[], shell?: string, cwd?: string, initial_input?: string, exit?: { on_completion?: boolean } } }
---@return rex.LayoutSpec
function rex.layout.block(spec) end

---@param ratio number share given to a
---@param a rex.LayoutSpec
---@param b rex.LayoutSpec
---@return rex.LayoutSpec
function rex.layout.horizontal(ratio, a, b) end

---@param ratio number share given to a
---@param a rex.LayoutSpec
---@param b rex.LayoutSpec
---@return rex.LayoutSpec
function rex.layout.vertical(ratio, a, b) end

-- events (scripts only)

---@param event rex.EventName|string
---@param fn fun(ctx: rex.Context, ev: rex.Event)
function rex.on(event, fn) end

---@param event rex.EventName|string
---@param filter? table|fun(ev: rex.Event, ctx: rex.Context): boolean
---@param timeout? number seconds
---@return rex.Event|nil ev, rex.Context|"timeout" ctx
---@overload fun(event: rex.EventName|string, timeout: number): rex.Event|nil, rex.Context|"timeout"
function rex.wait(event, filter, timeout) end

---@param seconds number
function rex.sleep(seconds) end

---@param code? integer
function rex.stop(code) end

---@param seconds number
---@param fn fun(ctx: rex.Context)
---@return rex.Timer
function rex.after(seconds, fn) end

---@param seconds number must be more than zero
---@param fn fun(ctx: rex.Context)
---@return rex.Timer
function rex.every(seconds, fn) end

-- hosts and other servers

---@param spec rex.HostSpec
function rex.host(spec) end

---@return string[]
function rex.servers() end

-- calls through it don't fill in session_id or block_id. raises for an unknown label
---@param label string
---@return rex.Server
function rex.server(label) end

-- other

rex.json = {}

---@param value any
---@param opts? { indent?: boolean }
---@return string?, string?
function rex.json.encode(value, opts) end

---@param text string
---@return any, string?
function rex.json.decode(text) end

---@param level "debug"|"info"|"warn"|"error"
---@param message string
---@overload fun(message: string)
function rex.log(level, message) end
