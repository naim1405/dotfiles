
return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local colors = {
      color2 = '#242b38',
      color3 = '#d4bfff',
      color4 = '#d9d7ce',
      color5 = '#272d38',
      color13 = '#bbe67e',
      color10 = '#59c2ff',
      color8 = '#f07178',
      color9 = '#607080',
      orange = '#fe8019',
      red = '#ca1243',
    }

    local theme = {
      visual = {
        a = { fg = colors.color2, bg = colors.color3, gui = 'bold' },
        b = { fg = colors.color4, bg = colors.color5 },
      },
      replace = {
        a = { fg = colors.color2, bg = colors.color8, gui = 'bold' },
        b = { fg = colors.color4, bg = colors.color5 },
      },
      inactive = {
        c = { fg = colors.color4, bg = colors.color2 },
        a = { fg = colors.color4, bg = colors.color5, gui = 'bold' },
        b = { fg = colors.color4, bg = colors.color5 },
      },
      normal = {
        c = { fg = colors.color9, bg = colors.color2 },
        a = { fg = colors.color2, bg = colors.color10, gui = 'bold' },
        b = { fg = colors.color4, bg = colors.color5 },
      },
      insert = {
        a = { fg = colors.color2, bg = colors.color13, gui = 'bold' },
        b = { fg = colors.color4, bg = colors.color5 },
      },
    }
    local empty = require('lualine.component'):extend()
    function empty:draw(default_highlight)
      self.status = ''
      self.applied_separator = ''
      self:apply_highlights(default_highlight)
      self:apply_section_separators()
      return self.status
    end

    -- Put proper separators and gaps between components in sections
    local function process_sections(sections)
      for name, section in pairs(sections) do
        local left = name:sub(9, 10) < 'x'
        for pos = 1, name ~= 'lualine_z' and #section or #section - 1 do
          table.insert(section, pos * 2, { empty, color = { fg = colors.color2, bg = colors.color2 } })
        end
        for id, comp in ipairs(section) do
          if type(comp) ~= 'table' then
            comp = { comp }
            section[id] = comp
          end
          comp.separator = left and { right = '' } or { left = '' }
        end
      end
      return sections
    end

    local function search_result()
      if vim.v.hlsearch == 0 then
        return ''
      end
      local last_search = vim.fn.getreg '/'
      if not last_search or last_search == '' then
        return ''
      end
      local searchcount = vim.fn.searchcount { maxcount = 9999 }
      return last_search .. '(' .. searchcount.current .. '/' .. searchcount.total .. ')'
    end

    local function modified()
      if vim.bo.modified then
        return '+'
      elseif vim.bo.modifiable == false or vim.bo.readonly == true then
        return '-'
      end
      return ''
    end

    require('lualine').setup {
      options = {
        theme = theme,
        component_separators = '',
        section_separators = { left = '', right = '' },
        disabled_filetypes = { 'NvimTree' },
      },
      sections = process_sections {
        lualine_a = { 'mode' },
        lualine_b = {
          'branch',
          'diff',
          {
            'diagnostics',
            source = { 'nvim' },
            sections = { 'error' },
            diagnostics_color = { error = { bg = colors.red, fg = colors.color2 } },
          },
          {
            'diagnostics',
            source = { 'nvim' },
            sections = { 'warn' },
            diagnostics_color = { warn = { bg = colors.orange, fg = colors.color2 } },
          },
          { 'filename', file_status = false, path = 1 },
          { modified, color = { bg = colors.red } },
          {
            '%w',
            cond = function()
              return vim.wo.previewwindow
            end,
          },
          {
            '%r',
            cond = function()
              return vim.bo.readonly
            end,
          },
          {
            '%q',
            cond = function()
              return vim.bo.buftype == 'quickfix'
            end,
          },
        },
        lualine_c = {},
        lualine_x = {},
        lualine_y = { search_result, 'filetype' },
        lualine_z = { '%l:%c', '%p%%/%L' },
      },
      inactive_sections = {
        lualine_c = { '%f %y %m' },
        lualine_x = {},
      },
    }
  end,
}
