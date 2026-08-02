# Android VPN Bridge

Канал: `pro.batmin.connect/vpn`

Методы:

- `prepare` — вызывает `VpnService.prepare()` и системный диалог разрешения;
- `start` — запускает foreground VPN service;
- `stop` — останавливает сервис;
- `status` — возвращает `stopped`, `starting`, `ready`, `stopping` или `error`.

`BatminVpnService` пока является мостом жизненного цикла. Libbox будет запускаться до `VpnService.Builder.establish()`, чтобы исключить потерю сети при ошибке ядра.
