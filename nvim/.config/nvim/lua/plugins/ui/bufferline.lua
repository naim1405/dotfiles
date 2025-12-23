return {
  'akinsho/bufferline.nvim',
  version = '*',
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = function()
    require('bufferline').setup {
      options = {
        offsets = {
          {
            filetype = 'NvimTree',
            text = 'File Explorer',
            highlight = 'Directory',
            separator = true, -- use a "true" to enable the default, or set your own character
          },
        },
        themable = true, -- allows highlight groups to be overriden i.e. sets highlights as default
        icon_pinned = '󰐃',
        buffer_close_icon = '✗',
        close_icon = '✗',
        left_trunc_marker = '',
        right_trunc_marker = '',
        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = true,
        --sort_by = 'insert_at_end',
        sort_by = 'insert_after_current',
        --indicator_icon = '| ',
        indicator_icon = '⏽ ',
        indicator = {
          style = 'icon',
        },
        separator_style = 'thick',
        mode = 'buffers',
        move_wraps_at_ends = true,
        right_mouse_command = 'vert sbuffer %d',
        diagnostics = 'nvim_lsp',
        diagnostics_update_in_insert = false,
        hover = { enabled = true, reveal = { 'close' } },
      },
      highlights = {
        indicator_selected = {
          fg = {
            attribute = 'fg',
            highlight = 'Function',
          },
        },
      },
    }

    --bufferline keymaps
    vim.keymap.set('n', '[b', '<cmd>BufferLineMoveNext<CR>', { desc = 'bufferline: move next' })
    vim.keymap.set('n', ']b', '<cmd>BufferLineMovePrev<CR>', { desc = 'bufferline: move prev' })
    vim.keymap.set('n', '<leader>bb', '<cmd>BufferLinePick<CR>', { desc = 'bufferline: pick buffer' })
    vim.keymap.set('n', '<leader>bd', '<cmd>BufferLinePickClose<CR>', { desc = 'bufferline: delete buffer' })
    vim.keymap.set('n', '<S-Tab>', '<Cmd>BufferLineCyclePrev<CR>', { desc = 'bufferline: prev' })
    vim.keymap.set('n', '<Tab>', '<Cmd>BufferLineCycleNext<CR>', { desc = 'bufferline: next' })
  end,
}
