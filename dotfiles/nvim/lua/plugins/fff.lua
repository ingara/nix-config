return {
  "dmtrKovalenko/fff.nvim",
  -- build = function()
  --   -- this will download prebuild binary or try to use existing rustup toolchain to build from source
  --   -- (if you are using lazy you can use gb for rebuilding a plugin if needed)
  --   require("fff.download").download_or_build_binary()
  -- end,
  -- if you are using nixos
  build = "nix run .#release",
  -- No need to lazy-load with lazy.nvim.
  -- This plugin initializes itself lazily.
  lazy = false,
  keys = {
    {
      "ff",
      function()
        require("fff").find_in_git_root()
      end,
      desc = "FFFind files in git repo",
    },
    {
      "fF",
      function()
        require("fff").find_files()
      end,
      desc = "FFFind files in project",
    },
  },
}
