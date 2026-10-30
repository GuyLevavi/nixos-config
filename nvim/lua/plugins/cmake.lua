-- Each command builds first; Debug hands the target to nvim-dap (codelldb, see dap.lua).
return {
  {
    "Civitasv/cmake-tools.nvim",
    opts = { cmake_virtual_text_support = false },
    keys = {
      { "<leader>mb", "<cmd>CMakeBuild<cr>", desc = "Build" },
      { "<leader>mr", "<cmd>CMakeRun<cr>", desc = "Run" },
      { "<leader>md", "<cmd>CMakeDebug<cr>", desc = "Debug" },
      { "<leader>mt", "<cmd>CMakeSelectLaunchTarget<cr>", desc = "Select Target" },
      { "<leader>mp", "<cmd>CMakeSelectConfigurePreset<cr>", desc = "Select Preset" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>m", group = "cmake", icon = { icon = "", color = "blue" } } } },
  },
}
