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

or as a function that recieves the path to the file and returns the command:

```lua
{
  sources = {
    python = function(filepath)
      local on_windows = vim.uv.os_uname().sysname == "Windows_NT"
      return {
        on_windows and "py" or "python3",
        filepath,
        "-",
        vim.version().build, -- Pass Neovim version as an argument
      }
    end
  },
}
```

When you pass a list of strings to the functions, the path to the scratch file
gets appended automatically to the list before calling the executable. You
can also pass a function that takes the path and returns the command
(`fun(filepath: string): string[]`) if you wish to manage this process
yourself.

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

    ---Commands that run your script. See :h scratch-runner.SourceSpec
    ---@type table<string, scratch-runner.SourceSpec>
    sources = {},
}
```
