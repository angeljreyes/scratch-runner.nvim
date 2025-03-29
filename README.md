# scratch-runner.nvim
Plugin for quickly adding running capabilities to `snacks.scratch`.

https://github.com/user-attachments/assets/dfe81c00-51e1-45c2-836d-2649e128ee4b

## Requirements
Same requirements as [snacks.nvim](https://github.com/folke/snacks.nvim/tree/main#%EF%B8%8F-requirements).

## Installation

<details>
  <summary>With 
    <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a>
  </summary>

  ```lua
  {
    "DestopLine/scratch-runner.nvim",
    dependencies = "folke/snacks.nvim",
    opts = {
      -- Your options go here
    },
  }
  ```

</details>

<details>
  <summary>With 
    <a href="https://github.com/echasnovski/mini.deps">mini.deps</a>
  </summary>

  ```lua
  MiniDeps.add({
    source = "DestopLine/scratch-runner.nvim",
    depends = "folke/snacks.nvim",
  })

  require("scratch-runner").setup({
    -- Your options go here
  })
  ```

</details>

<details>
  <summary>With 
    <a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a>
  </summary>

  ```lua
  use({
    "DestopLine/scratch-runner.nvim",
    after = "snacks.nvim",
    config = function()
      require("scratch-runner").setup({
        -- Your options go here
      })
    end,
  })
  ```

</details>

<details>
  <summary>With 
    <a href="https://github.com/junegunn/vim-plug">vim-plug</a>
  </summary>

  ```vim
  Plug 'folke/snacks.nvim'
  " ...
  Plug 'DestopLine/scratch-runner.nvim'

  lua << EOF
  require("scratch-runner").setup({
    -- Your options go here
  })
  EOF
  ```

</details>

## Usage

In order to use the plugin, you need to add some sources to the plugin
configuration as commands in the form of lists of strings:

```lua
{
  sources = {
    javascript = { "node" },
    python = { "python3" }, -- "py" or "python" if you are on Windows
  },
}
```

or as functions that recieve the path to the file and the path to a binary,
and return the command:

```lua
{
  sources = {
    python = function(file_path)
      local on_windows = vim.uv.os_uname().sysname == "Windows_NT"
      return {
        on_windows and "py" or "python3",
        file_path,
        "-",
        vim.version().build, -- Pass Neovim version as an argument
      }
    end
  },
}
```

You can also pass either one of these to a table with extra options:

```lua
{
  sources = {
    typescript = {
      { "deno" },
      extension = "ts",
    },
  },
}
```

or:

```lua
{
  sources = {
    rust = {
      function(file_path, bin_path)
        return { "rustc", file_path, "-o", bin_path }
      end,
      extension = "rs",
      binary = true,
    },
  },
}
```

The function can also return a list of commands. In fact, in the previous
example, `binary = true` is just a shortcut for this:

```lua
{
  sources = {
    rust = {
      function(file_path, bin_path)
        return {
          { "rustc", file_path, "-o", bin_path },
          { bin_path },
        }
      end,
      extension = "rs",
    },
  },
}
```

When using the `extension` option, the plugin will copy the `snacks.scratch`
file to a temporary directory with the correct file extension. This is useful
when a runtime/compiler is giving you an error or behaving unexpectedly due to
scratch files having the wrong file extension (e.g. `python` instead of `py`)
or having percentage signs in the file name.

When you are in a scratch window, you can press `<CR>` to run the buffer.
You can also select some lines in visual mode and press `<CR>` to run only the
selected lines. You can press `q` to cancel the execution of the script while
it's running. Once the script is done running, you can see the standard output
and/or the standard error of the process. If the process wrote to both stdout
and stderr, you can switch between the two with `<Tab>`.

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

    ---Commands that run your script. See :h scratch-runner.Source
    ---@type table<string, scratch-runner.Source | scratch-runner.SourceCommand>
    sources = {},
}
```
