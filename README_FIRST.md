# Batmin Connect v0.6.0 — Foundation

Это исходный код первого фактического этапа разработки интерфейса и Android VPN-моста.

## Реализовано
- фирменный главный экран;
- программно нарисованная и анимированная летучая мышь;
- состояния disconnected / connecting / connected;
- запрос Android VPN permission через MethodChannel;
- foreground VpnService и уведомление;
- экраны серверов, диагностики и настроек;
- профиль Hysteria2 для дальнейшей интеграции.

## Честный статус
Проект пока **не маршрутизирует трафик через Hysteria2**, потому что libbox/sing-box engine ещё не подключён. VpnService является рабочим Android-каркасом, но не полноценным туннелем.

## Сборка
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Требуются Flutter SDK, Android SDK и JDK 17/21.
