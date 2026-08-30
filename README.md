# NekoBox routing profiles

Удалённый каталог профилей маршрутизации для NekoBox 5.11.24.

## Содержимое

- `catalog.json` — список, отображаемый через «Загрузка профилей».
- `profiles/by-oleg.json` — выборочный VPN для Brave, Discord и Telegram;
  российские и белорусские назначения идут напрямую.
- `profiles/all-through-vpn-except-ru.json` — российские IP и домены напрямую,
  остальной трафик через VPN.
- `client-overlay/public/check_routeprofiles.js` — файл для папки `public`
  переносной сборки NekoBox.
- `tools/validate.py` — локальная проверка каталога и профилей.

## Первичная загрузка

Загрузите всё содержимое архива в корень ветки `main`. После публикации должны
открываться ссылки:

- `https://raw.githubusercontent.com/T1Legendary/nekobox-routing-profiles/main/catalog.json`
- `https://raw.githubusercontent.com/T1Legendary/nekobox-routing-profiles/main/profiles/by-oleg.json`
- `https://raw.githubusercontent.com/T1Legendary/nekobox-routing-profiles/main/profiles/all-through-vpn-except-ru.json`

Ссылки в `catalog.json` намеренно остаются ссылками на GitHub: это канонические
адреса источника. Файл `client-overlay/public/check_routeprofiles.js` передаёт
их функции `get_jsdelivr_link()`, а клиент с `ruleset_mirror = 1` фактически
загружает каталог и профили через jsDelivr. Это позволяет работать в сетях, где
`raw.githubusercontent.com` недоступен.

Скопируйте `client-overlay/public/check_routeprofiles.js` в папку `public`
рядом с `nekobox.exe`. В готовом архиве настроек этот файл уже лежит в нужном
месте. Саму папку `client-overlay` полезно хранить в репозитории как резервную
копию клиентского файла; NekoBox не загружает этот JS из репозитория автоматически.

## Обновление существующего профиля

Измените соответствующий JSON в `profiles` и загрузите новую версию в `main`.
Клиенты получат её через «Обновление → Профили маршрутизации».

В NekoBox 5.11.24 после массового обновления нужно открыть «Редактировать
профили маршрутизации» и подтвердить окно кнопкой OK — это сохранит новые правила
на диск. Затем переподключите активный сервер, чтобы новая маршрутизация
применилась к работающему соединению.

## Добавление профиля

1. Добавьте новый JSON-массив правил в `profiles`.
2. Добавьте запись в `catalog.json` с уникальным `id`, названием, raw-ссылкой и
   `default_outbound` (`direct` или `proxy`).
3. Выполните `python3 tools/validate.py` и загрузите изменения.
4. Если окно «Загрузка профилей» уже открывалось в текущем сеансе NekoBox,
   перезапустите программу для обновления кэшированного списка.

Не загружайте сюда папку `settings`, VLESS-ссылки, UUID, ключи Reality или
другие параметры серверов.

## Ошибка `parse rule-set[0]: EOF`

Она означает, что клиент пытается разобрать пустой или недокачанный `.srs`.
Закройте NekoBox, удалите старую папку `settings` и установите полный архив
настроек с зеркалом jsDelivr. Простая замена одного JSON не удаляет повреждённый
кэш, поэтому для этого случая нужна чистая замена папки.
