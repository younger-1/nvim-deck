-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    {
      "hrsh7th/nvim-deck",
      config = function()
        local deck = require('deck')

        require('deck.easy').setup()

        vim.api.nvim_create_autocmd('User', {
          pattern = 'DeckStart',
          callback = function(e)
            local ctx = e.data.ctx --[[@as deck.Context]]
            ctx.keymap('n', '<Tab>', deck.action_mapping('choose_action'))
            ctx.keymap('n', '<C-l>', deck.action_mapping('refresh'))
            ctx.keymap('n', 'i', deck.action_mapping('prompt'))
            ctx.keymap('n', 'a', deck.action_mapping('prompt'))
            ctx.keymap('n', '@', deck.action_mapping('toggle_select'))
            ctx.keymap('n', '*', deck.action_mapping('toggle_select_all'))
            ctx.keymap('n', 'p', deck.action_mapping('toggle_preview_mode'))
            ctx.keymap('n', 'd', deck.action_mapping('delete'))
            ctx.keymap('n', '<CR>', deck.action_mapping('default'))
            ctx.keymap('n', 'o', deck.action_mapping('open'))
            ctx.keymap('n', 'O', deck.action_mapping('open_keep'))
            ctx.keymap('n', 's', deck.action_mapping('open_s'))
            ctx.keymap('n', 'v', deck.action_mapping('open_v'))
            ctx.keymap('n', 'N', deck.action_mapping('create'))
            ctx.keymap('n', '<C-u>', deck.action_mapping('scroll_preview_up'))
            ctx.keymap('n', '<C-d>', deck.action_mapping('scroll_preview_down'))
          end
        })

        vim.keymap.set('n', '<Leader>ff', '<Cmd>Deck files<CR>', { desc = 'Show recent files, buffers, and more' })
        vim.keymap.set('n', '<Leader>gr', '<Cmd>Deck grep<CR>', { desc = 'Start grep search' })
        vim.keymap.set('n', '<Leader>gi', '<Cmd>Deck git<CR>', { desc = 'Open git launcher' })
        vim.keymap.set('n', '<Leader>he', '<Cmd>Deck helpgrep<CR>', { desc = 'Live grep all help tags' })

        vim.keymap.set('n', '<Leader>;', function()
          local ctx = require('deck').get_history()[1]
          if ctx then
            ctx.show()
          end
        end)
      end
    }
  },
  -- automatically check for plugin updates
  checker = { enabled = true },
})
