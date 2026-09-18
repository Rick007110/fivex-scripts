# fivex_zombies NUI — UIXpert → FiveXpert

Files: `/workspace/fivex_zombies/html/{index.html,style.css,app.js}` (+ `ALARM.md`)

## Wire in fxmanifest
```lua
ui_page 'html/index.html'
files {
  'html/index.html',
  'html/style.css',
  'html/app.js',
  'html/audio/alarm.ogg',
}
```

## Messages (`SendNUIMessage`)

### Announce
```lua
-- Start
SendNUIMessage({
  action = 'announce',
  kind = 'start',
  title = 'APOCALYPSE',           -- optional
  subtitle = 'All civs infected — prepare', -- optional
  grace = 30,                     -- seconds; omit to hide countdown
  durationMs = 9000,              -- auto-hide (default ~9s start / ~8s stop)
})

-- Stop
SendNUIMessage({
  action = 'announce',
  kind = 'stop',
  title = 'ALL CLEAR',
  subtitle = 'Streets returning to normal',
  durationMs = 8000,
})
```

### Alarm
```lua
SendNUIMessage({ action = 'playAlarm', src = 'audio/alarm.ogg', volume = 0.5 })
-- optional loopMs = 4000 to re-trigger; else HTMLAudio loop=true
SendNUIMessage({ action = 'stopAlarm' })
```

## Design
- FiveX tokens; danger `#e85d5d` pulse on start; calm accent on stop
- Transparent body, no cursor, `pointer-events: none` — overlay only
- No CDNs / frameworks
