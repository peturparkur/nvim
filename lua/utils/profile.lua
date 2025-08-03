local PROFILES = {
  ['HOME'] = {
    'python',
    'nix',
    'go',
    'rust',
    'markdown',
    'bash',
    'docker',
    'lua',
    'yaml',
  },
  ['DEFAULT'] = {
    'python',
    'markdown',
    'bash',
    'docker',
    'lua',
    'yaml',
  },
}

local Profile = {}
Profile.Languages = function()
  local profile = PROFILES[os.getenv 'NVIM_PROFILE' or 'DEFAULT']
  return profile
end

return Profile
