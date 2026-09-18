Config = {}
Config.Locale = 'en'
Config.OpenCommand = 'flexa'
Config.OpenKey = 'F1' -- RegisterKeyMapping; players can rebind
Config.FoldKey = 'G'
Config.DefaultFolded = true
Config.FoldAnimMs = 500
Config.UsePhoneAnim = false -- NUI-only; skip ped anim when false
Config.PhoneAnim = {
  open = { dict = 'cellphone@', anim = 'cellphone_text_in', flag = 50 },
  close = { dict = 'cellphone@', anim = 'cellphone_text_out', flag = 48 },
}
Config.PhoneNumberPrefix = '555'
Config.MaxMessageLength = 500
Config.SmsRateLimitMs = 800
Config.CallTimeoutMs = 30000
Config.VoiceBridge = 'auto' -- auto|pma-voice|none

-- Now Bar (live activity / notification strip; UI in Whiz UI 1.2)
Config.NowBarMax = 5

-- Camera / Gallery
Config.MaxGalleryPhotos = 30
Config.ScreenshotResource = 'screenshot-basic' -- ensure before fivex_flexa for real captures

-- Persisted Settings defaults (client KVP; pushed as setSettings)
Config.SettingsDefaults = {
  wallpaper = 'aurora', -- gradient presets: default|dark|aurora|sunset|ocean
  foldAnimMs = 560,
  soundEnabled = true,
  vibration = true,
  darkMode = true,
  nowBarEnabled = true,
  airplaneMode = false,
  wifiFake = true,
  bluetoothFake = false,
  locationFake = true,
  brightness = 80,
  textSize = 'default', -- small|default|large
  clockFormat = '24h', -- '24h'|'12h' — status, widgets, clock app, message times
}

-- Core always installed (cannot uninstall)
Config.CoreApps = { 'phone', 'messages', 'settings', 'store' }

-- Full catalog (home shows installed only)
Config.AppCatalog = {
  { id = 'phone', label = 'Phone', icon = 'phone', color = '#34c759', blurb = 'Place and receive calls from the dialer and contacts.', category = 'Essentials', core = true },
  { id = 'messages', label = 'Messages', icon = 'messages', color = '#5b8def', blurb = 'SMS threads between players with live delivery.', category = 'Essentials', core = true },
  { id = 'settings', label = 'Settings', icon = 'settings', color = '#8e8e93', blurb = 'Wallpaper, fold timing, sound, brightness, clock format, and Now Bar.', category = 'Essentials', core = true },
  { id = 'store', label = 'Store', icon = 'store', color = '#007aff', blurb = 'Browse and install Flexa apps from Whiz Store.', category = 'Essentials', core = true },
  { id = 'notes', label = 'Notes', icon = 'notes', color = '#f5d76e', blurb = 'Jot quick notes that stay on this phone.', category = 'Tools' },
  { id = 'calculator', label = 'Calculator', icon = 'calc', color = '#8b9bb0', blurb = 'Everyday calculator for quick math on the go.', category = 'Tools' },
  { id = 'weather', label = 'Weather', icon = 'weather', color = '#64d2ff', blurb = 'Local city forecast stub with temp and wind.', category = 'Lifestyle' },
  { id = 'browser', label = 'Browser', icon = 'browser', color = '#bf5af2', blurb = 'Quick links and a simple address-bar stub.', category = 'Tools' },
  { id = 'gallery', label = 'Gallery', icon = 'gallery', color = '#ff375f', blurb = 'Browse photos captured with Camera.', category = 'Lifestyle' },
  { id = 'clock', label = 'Clock', icon = 'clock', color = '#ff9f0a', blurb = 'Live digital clock with alarm stubs.', category = 'Tools' },
  { id = 'contacts', label = 'Contacts', icon = 'contacts', color = '#30d158', blurb = 'People on Flexa numbers — tap to call.', category = 'Essentials' },
  { id = 'camera', label = 'Camera', icon = 'camera', color = '#ff6482', blurb = 'Capture in-world photos into Gallery (needs screenshot-basic).', category = 'Lifestyle' },
}

-- Default install set (extras optional; core always forced in by client)
Config.DefaultInstalled = { 'phone', 'messages', 'settings', 'store', 'notes', 'calculator', 'camera', 'gallery' }

-- Backward-compat home list derived from catalog + defaults (client overrides with KVP)
do
  local byId = {}
  for i = 1, #Config.AppCatalog do
    local e = Config.AppCatalog[i]
    byId[e.id] = e
  end
  local apps = {}
  for i = 1, #Config.DefaultInstalled do
    local id = Config.DefaultInstalled[i]
    local e = byId[id]
    if e then
      apps[#apps + 1] = { id = e.id, label = e.label, icon = e.icon, color = e.color }
    end
  end
  Config.Apps = apps
end

Config.Brand = { name = 'Flexa', maker = 'Whiz Mobile', tagline = 'Unfold your world.' }
Config.Debug = false
