Alarm asset: `audio/alarm.ogg` (vorbis siren).

Default NUI path is already `audio/alarm.ogg`.

```lua
SendNUIMessage({ action = 'playAlarm', src = 'audio/alarm.ogg', volume = 0.5 })
SendNUIMessage({ action = 'stopAlarm' })
```

fxmanifest `files` must include `html/audio/alarm.ogg`.
