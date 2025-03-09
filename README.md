# scratch-runner.nvim
Library plugin for quickly adding running capabilities to your `snacks.scratch`
configuration.

## Requirements
Same requirements as [snacks.nvim](https://github.com/folke/snacks.nvim/tree/main#%EF%B8%8F-requirements).

## Installation
> [!NOTE]
> You don't need to call `require("scratch-runner").setup()` to enable the
> plugin.

<details>
  <summary>With 
    <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a>
  </summary>

  ```lua
  {
    "DestopLine/scratch-runner.nvim",
    dependencies = "folke/snacks.nvim"
    -- Optional
    opts = {
      -- Your options go here
    },
  }
  ```

</details>

## Usage

> [!WARNING]
> In `lazy.nvim`, you should pass a function to `opts` instead of just a
> table if you want to eliminate the risk of calling
> `require("scratch-runner")` before the plugin is installed and getting a
> `module not found` error. If you have more than one definition of
> `"folke/snacks.nvim"` in your config, this function must mutate the `opts`
> table it gets through its second parameter and return nothing.
> See lazy's [Spec Setup](https://lazy.folke.io/spec#spec-setup) for more
> details. See [Example Config](#example-config) down below for an example.

Inside your `snacks.nvim` options, you can use the `make_win_by_ft()` function
and pass the result to `opts.scratch.win_by_ft`:

```lua
{
  scratch = {
    win_by_ft = require("scratch-runner").make_win_by_ft({
      javascript = { "node" },
      python = { "python3" }, -- "py" or "python" if you are on Windows
    }),
  },
}
```

or just create the key for one filetype:

```lua
{
  scratch = {
    win_by_ft = {
      javascript = {
        keys = {
          run = require("scratch-runner").make_key({ "node" })
        },
      },
    },
  },
}
```

The latter is more verbose, but allows you to add other keys and options to
the filetype in addition to the "run buffer" key.

> [!NOTE]
> It is recommended that you do `keys = { run = make_key() }` instead of
> `keys = { make_key() }`, as the latter will replace the default keymaps like
> `q` for close.

When you pass a list of strings to the functions, the path to the scratch file
gets appended automatically to the list before calling the executable. You
can also pass a function that take the path and returns the command
(`fun(filepath: string): string[]`) if you wish to manage this process
yourself.

As a second parameter to both of these functions you can pass a table with
the same options you see in [Default Config](#default-config).

When you are in a scratch window, you can press `<CR>` to run the buffer.
You can press `q` to cancel the execution of the script while it's running.
Once the script is done running, you can see the standard output and/or the
standard error of the process. If the process wrote to both stdout and stderr,
you can switch between the two with `<Tab>`.

<h2 id="default-config">Default Config</h2>

```lua
---@class scratch-runner.Config
H.config = {
    ---Key that runs the scratch buffer.
    ---@type string?
    run_key = "<CR>",

    ---Key that switches between stdout and stderr.
    ---@type string?
    output_switch_key = "<Tab>",
}
```

<h2 id="example-config">Example Config</h2>

This is and simplified excerpt from my Neovim config, where I have divided
`folke/snacks.nvim` into different files:

```lua
return {
  {
    "DestopLine/scratch-runner.nvim",
    dependencies = "folke/snacks.nvim",
  },

  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.scratch = {
        enabled = true,
        win_by_ft = require("scratch-runner").make_win_by_ft({
          python = { Utils.on_windows and "py" or "python3" },
          javascript = { "node" },
          cs = { "dotnet-script" },
        }),
      }
    end
  },
}
```

> [!NOTE]
> `Utils.on_windows` is equal to `vim.uv.os_uname().sysname == "Windows_NT"`.
