local function transparent()
  local groups = {
    "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn",
    "LineNr", "CursorLineNr", "EndOfBuffer", "FoldColumn", "StatusLine",
    "StatusLineNC", "WinSeparator", "MsgArea",
  }
  for _, group in ipairs(groups) do
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    hl.bg = nil
    hl.ctermbg = nil
    vim.api.nvim_set_hl(0, group, hl)
  end
end

vim.api.nvim_create_autocmd("ColorScheme", { callback = transparent })
transparent()
