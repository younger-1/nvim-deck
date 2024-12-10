local VFile = {}
VFile.__index = VFile

function VFile.new(path)
  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile({}, path)
  end

  local self = setmetatable({}, VFile)
  self.path = path
  self.contents = vim.fn.readfile(path)
  self.autocmd_id = vim.api.nvim_create_autocmd('VimLeavePre', {
    desc = 'deck.helper.VFile',
    callback = function()
      vim.fn.writefile(self.contents, self.path)
    end
  })
  return self
end

return VFile
