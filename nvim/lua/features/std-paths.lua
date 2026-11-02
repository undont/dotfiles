-- GO_STD, RUST_STD and ZIG_STD for `:e $ZIG_STD/...`, resolved async so startup doesn't wait on the toolchains
local M = {}

local sources = {
  GO_STD = {
    cmd = { 'go', 'env', 'GOROOT' },
    path = function(out)
      return vim.trim(out) .. '/src'
    end,
  },
  RUST_STD = {
    cmd = { 'rustc', '--print', 'sysroot' },
    path = function(out)
      return vim.trim(out) .. '/lib/rustlib/src/rust/library'
    end,
  },
  ZIG_STD = {
    cmd = { 'zig', 'env' },
    path = function(out)
      return out:match '%.std_dir = "(.-)"'
    end,
  },
}

function M.setup()
  for name, source in pairs(sources) do
    if vim.env[name] == nil and vim.fn.executable(source.cmd[1]) == 1 then
      vim.system(source.cmd, { text = true }, function(result)
        if result.code ~= 0 then
          return
        end
        local path = source.path(result.stdout)
        if path then
          vim.schedule(function()
            vim.env[name] = path
          end)
        end
      end)
    end
  end
end

return M
