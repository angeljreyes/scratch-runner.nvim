# Contributing
To contribute to this plugin, just fork the repository, make your own branch,
add your changes and make the pull request.

## Style
Lua files in this repository use 4 spaces as indentation. Always declare
private functions in the form of `H.my_function = function()` and public
functions as `M.my_function = function()`. Always document functions, public
or private, in order to make it easy for others to understand the code and
contribute to it.

Always run `stylua` to format your files according to `stylua.toml` before
commiting. You shouldn't format files that you didn't touch.

Try to keep the line length of markdown files <= 78 characters. It's easier to
do this if you `:set textwidth=78` and format your lines with `gq` or `gw`.

## Documentation
Always document public APIs on the `docs/` directory. Try to keep the style as
consistent as possible. Some things are documented both on the docs and on the
README, you should update both when this is the case (for example, when adding
support for a language).

## Commits
Always use [conventional
commits](https://gist.github.com/qoomon/5dfcdf8eec66a051ecd85625518cfd13) for
your commit messages. This makes it easier to understand the context around
the commit and makes it so that `lazy.nvim` highlights the commits based on
their type; pretty useful for our beloved users.

## Adding a source
When adding a source, add the code on the table returning from
`lua/scratch-runner/sources.lua`, then document it on
`docs/scratch-runner.txt` and `README.md`. Also place it in alphabetical order
in all 3 of these files please :).

You can check out the [usage](./README.md#usage) section on the README to learn
how to add a source. You should know that the sources table in `sources.lua`,
unlike the `sources` field of the plugin configuration, can't take
`scratch-runner.SourceCommand` as a value, but instead can only take
`scratch-runner.Source`.
