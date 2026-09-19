# scratch-runner.nvim
Plugin for quickly adding running capabilities to `snacks.scratch`.

https://github.com/user-attachments/assets/a1c6843a-e212-4c27-b76c-d23bdfba4ebc

## Requirements
Same requirements as [snacks.nvim](https://github.com/folke/snacks.nvim/tree/main#%EF%B8%8F-requirements) plus the following:
- Neovim >= 0.10

## Installation

<details>
  <summary>With 
    <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a>
  </summary>

  ```lua
  {
    "angeljreyes/scratch-runner.nvim",
    dependencies = "folke/snacks.nvim",
  }
  ```

</details>

<details>
  <summary>With 
    <a href="https://github.com/echasnovski/mini.deps">mini.deps</a>
  </summary>

  ```lua
  MiniDeps.add({
    source = "angeljreyes/scratch-runner.nvim",
    depends = "folke/snacks.nvim",
  })
  ```

</details>

<details>
  <summary>With 
    <a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a>
  </summary>

  ```lua
  use({
    "angeljreyes/scratch-runner.nvim",
    after = "snacks.nvim",
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
  Plug 'angeljreyes/scratch-runner.nvim'
  ```

</details>

## Default sources

`scratch-runner.nvim` comes pre-configured with the following sources and each one
requires at least one of the dependencies specified in parenthesis to be available
in `PATH`. If you have multiple dependencies installed, the first one found from
left to right will be used. For example, if both `deno` and `node` are installed in
your system, `deno` will be used, since it comes before `node` on the list.
- Bash (`bash`)
- C (`gcc`, `clang`)
- C3 (`c3c`)
- Clojure (`bb`, `clojure`, `lein`)
- C++ (`g++`, `clang++`)
- Crystal (`crystal`)
- C# (`dotnet` >= 10, `dotnet-script`)
- D (`dmd`, `gdc`, `ldc`)
- Dart (`dart`)
- Batch (`cmd`, Windows Only)
- Erlang (`escript`)
- Fish (`fish`)
- Fortran (`gfortran`, `flang`, `flang-new`, `ifx`)
- F# (`dotnet`)
- Go (`go`)
- Groovy (`groovy`)
- Haskell (`runghc`)
- Html (Any browser)
- Java (`java`)
- JavaScript (`deno`, `bun`, `node`)
- Julia (`julia`)
- Kotlin (`kotlin`)
- Lisp (`sbcl`, `ecl`, `clisp`)
- Mojo (`mojo`)
- Nim (`nim`)
- Nushell (`nu`)
- OCaml (`ocaml`)
- Odin (`odin`)
- Pascal (`fpc`)
- Perl (`perl`)
- Php (`php`)
- Powershell (`powershell`, `pwsh`)
- Python (`python3`, `python`, `py`, `pypy3`)
- R (`Rscript`)
- Racket (`racket`)
- Ruby (`ruby`)
- Rust (`rustc`)
- Scala (`scala-cli`, `scala`)
- Scheme (`scheme`, `csi`, `chicken-csi`, `guile`)
- sh (`sh`)
- SML (`mlton`)
- Swift (`swift`)
- TypeScript (`deno`, `bun`, `node` >= 22.6.0, `npm exec tsx`)
- V (`v`)
- Visual Basic (`cscript`, Windows Only)
- Zig (`zig`)
- Zsh (`zsh`)

## Usage

You can use the plugin without any configuration, but if you wish to add a
language that isn't included in the default list of sources, or if you want to
override a default source, you can specify your own sources via
`require("scratch-runner").setup()`. A source can be specified in multiple
ways for convenience. It can be just a command in the form of a list of arguments:

```lua
{
  sources = {
    javascript = { "node" },
    go = { "go", "run" },
  },
}
```

or a function that takes in the path to the source file and the path to a binary,
and returns the command:

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
example, rust's `binary = true` is just a shortcut for this:

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

When using the `file_name` or `extension` options, the plugin will copy the
`snacks.scratch` file to a temporary directory with the correct name or file
extension. This is useful when a runtime/compiler is giving you an error or
behaving unexpectedly due to the scratch file having an invalid name (e.g. nim or
D files can't start with a number, which `snacks.nvim` uses for the file name),
the wrong file extension (e.g. `python` instead of `py`) or having percentage
signs in the file name.

When you are in a scratch window, you can press `<CR>` to run the buffer.
You can also select some lines in visual mode and press `<CR>` to run only the
selected lines. You can press `q` to cancel the execution of the file while
it's running. You can see the output of the build steps while they happen and
even send input to them or to your script, as the result window is just a
Neovim terminal buffer.

<h2 id="default-config">Default Config</h2>

```lua
---@class scratch-runner.Config
H.config = {
    ---Key that runs the scratch buffer.
    ---@type string?
    run_key = "<CR>",

    ---Commands that run your script. See :h scratch-runner.Source
    ---To see what sources are available by default,
    ---see :h scratch-runner-default-sources
    ---@type table<string, scratch-runner.Source | scratch-runner.SourceCommand>
    sources = {},
}
```
