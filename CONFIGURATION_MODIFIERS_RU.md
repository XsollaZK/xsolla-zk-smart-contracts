# Краткая справка: модификаторы `withConfiguration`, `defineInjection`, `defineUniqueInjection`

Этот проект использует систему основанную на `StdConfig` у Foundry для:
1. Подключения конфигурации окружения (debug / production).
2. Детерминированного вычисления адресов контрактов ("артефактов") до выполнения тела скрипта и проверки фактических адресов после.
3. (Опционально) обеспечения уникальности для прокси / экземпляров через `uniqueId`.

---
## 1. `withConfiguration(Kind.<...>)`
Модификатор загружает TOML конфиг из папки `./configurations/`:
- `withConfiguration(Kind.DEBUG)`  → `debug.toml`
- `withConfiguration(Kind.PRODUCTION)` → `production.toml`

Без вызова подходящего модификатора любая попытка использования зависимостей, основанных на конфиге, приведёт к ошибке `ChooseConfigurationFirst()`.

Есть также `withMultiChainConfiguration(...)` (если понадобится одновременная загрузка и форков нескольких сетей) — в справке не углубляемся, так как запрос касался базового варианта.

### Когда применять
Добавляйте его в модификаторную цепочку **первым** (или одним из первых), чтобы все последующие шаги имели доступ к загруженным в конфигурацию параметрам.

### Пример
```solidity
function run() public withConfiguration(Kind.DEBUG) { /* ... */ }
```

---
## 2. Артефакты (`Artifacts.Artifact`)
`Artifacts.Artifact` — enum, где каждая позиция соответствует определяемому в проекте контракту / типу деплоя. У артефактов есть вспомогательные методы (например, `toSalt()` / `toSalt(uniqueId)`), которые используются для детерминированного адреса через CREATE2 (или для прокси с определённым salt).

---
## 3. `defineInjection` (и семейство `defineInjectionsN`)
Модификатор:
- На вход принимает 1 (в случае `defineInjection`) или N (`defineInjections2`, `defineInjections3`, ... до 10) артефактов.
- До выполнения тела функции вычисляет ожидаемые детерминированные адреса для этих артефактов и сохраняет их во временный массив.
- После выполнения проверяет фактические адреса развёрнутых контрактов / прокси. Если адрес не совпал с ожидаемым — генерируется ошибка `ArtifactHasNotBeenInjected(name, actual)`.

### Для чего
Гарантирует, что в скрипте действительно был развёрнут контракт согласно ожидаемому salt/алгоритму адресации (защита от случайного пропуска деплоя либо неверного порядка).

### Пример (из `NativeCurrency.s.sol`)
```solidity
function run() 
    public 
    withConfiguration(Kind.DEBUG)
    defineInjections2(Artifacts.Artifact.WETH9, Artifacts.Artifact.Faucet) 
{
    vm.startBroadcast();
    weth9 = new WETH9{ salt: Artifacts.Artifact.WETH9.toSalt() }();
    faucet = new Faucet{ salt: Artifacts.Artifact.Faucet.toSalt() }();
    vm.stopBroadcast();
}
```
Если изменить salt или забыть задеплоить один из контрактов — модификатор обнаружит несоответствие.

> Одноартефактный случай: используйте `defineInjection(Artifacts.Artifact.WETH9)`.

---
## 4. `defineUniqueInjection` (и семейство `defineUniqueInjectionsN`)
Добавляет к логике обычных `defineInjection*` проверку уникальных идентификаторов (`bytes32 uniqueId[]`). Они обычно используются для:
- Развёртывания **нескольких** экземпляров одного и того же типа контракта (например, нескольких `TransparentUpgradeableProxy`) с разными уникальными salts.
- Явного документирования назначения прокси (повышает отслеживаемость и воспроизводимость).

### Механика
`defineUniqueInjection(Artifact.TransparentUpgradeableProxy, ID)`:
1. Вычисляет адрес с учётом `ID` (через вспомогательный метод `toSalt(ID)` или аналогичный путь внутри `_defineInjectionsPre`).
2. После тела функции проверяет, что действительно создан прокси по ожидаемому адресу.

### Пример (из `SSOWithXsollaProducts.s.sol`)
```solidity
bytes32 private constant ID_OF_TUP_XSOLLA_RECOVERY_EXECUTOR = 
    keccak256("TransparentUpgradeableProxy:xsolla-recovery-executor");

function deployFactory() 
    public 
    withConfiguration(Kind.DEBUG)
    defineUniqueInjection(
        Artifacts.Artifact.TransparentUpgradeableProxy, 
        ID_OF_TUP_XSOLLA_RECOVERY_EXECUTOR
    )
    returns (address factory, address[] memory extendedModules)
{
    // ... получение defaultModules из дочернего скрипта
    vm.startBroadcast();
    extendedModules[4] = _makeTUPWithId(
        address(new XsollaRecoveryExecutor(/* args */)),
        ID_OF_TUP_XSOLLA_RECOVERY_EXECUTOR
    );
    vm.stopBroadcast();
}
```
Если изменить `ID_OF_TUP_XSOLLA_RECOVERY_EXECUTOR` или не создать прокси — проверка провалится.

> Для нескольких уникальных артефактов используйте `defineUniqueInjections2`, `defineUniqueInjections3`, … до 10.

---
## 5. Типичная структура модификаторов
Рекомендуемый порядок в `run()` / `deploy*()` функциях:
1. `withConfiguration(Kind.DEBUG)` или `withConfiguration(Kind.PRODUCTION)` — загрузить конфиг.
2. `defineInjection...` / `defineUniqueInjection...` — зафиксировать ожидаемые адреса.
3. Внутри тела: `vm.startBroadcast();` → деплой контрактов по детерминированным salt → `vm.stopBroadcast();`.
4. (Опционально) логирование через `console.log`.

---
## 6. Краткие советы
- Если нужен один контракт — проще использовать `defineInjection` вместо `defineInjections2` и т.д.
- Если требуется несколько экземпляров одного типа (например, множество прокси одного имплемента), выбирайте `defineUniqueInjectionsN` и осмысленные `bytes32` идентификаторы.
- Не смешивайте обычные и уникальные модификаторы для одних и тех же артефактов в одной функции — избыток логики затруднит чтение.
- Конструируйте `uniqueId` так, чтобы при чтении было ясно назначение (`keccak256("TransparentUpgradeableProxy:xsolla-recovery-executor")`).

---
## 7. Минимальные примеры
### Один контракт
```solidity
function run() public withConfiguration(Kind.DEBUG) defineInjection(Artifacts.Artifact.WETH9) {
    vm.startBroadcast();
    new WETH9{ salt: Artifacts.Artifact.WETH9.toSalt() }();
    vm.stopBroadcast();
}
```

### Один уникальный прокси
```solidity
bytes32 constant ID = keccak256("TUP:my-feature");

function deploy() public withConfiguration(Kind.PRODUCTION) defineUniqueInjection(
    Artifacts.Artifact.TransparentUpgradeableProxy, ID
) {
    vm.startBroadcast();
    _makeTUPWithId(address(new SomeImpl()), ID);
    vm.stopBroadcast();
}
```

---
## 8. Запуск скриптов (пример)
(Замените RPC на нужный.)
```bash
forge script script/xsolla/NativeCurrency.s.sol:NativeCurrency --rpc-url $RPC --broadcast -vvvv
```
Для dry-run можно убрать `--broadcast`.

---
## 9. Возможные ошибки
- `ChooseConfigurationFirst()` — забыли модификатор `withConfiguration`.
- `UnknownConfiguration()` — передан неподдерживаемый `Kind`.
- `ArtifactHasNotBeenInjected(name, actual)` — артефакт не задеплоен по ожидаемому адресу (ошибка salt, порядка деплоя или сам деплой не выполнен).

---
## 10. Резюме
| Модификатор | Назначение | Когда использовать |
|-------------|------------|--------------------|
| `withConfiguration` | Загружает конфиг | Всегда перед деплоем, зависит от окружения |
| `defineInjection` / `defineInjectionsN` | Проверка детерминированных адресов артефактов | Когда деплоите фиксированный набор уникальных типов |
| `defineUniqueInjection` / `defineUniqueInjectionsN` | То же + уникальные идентификаторы (salt) | Когда несколько экземпляров одного типа или нужна явная идентификация |

Если потребуется расширенная документация — можно углубить разделы про внутреннюю реализацию `_defineInjectionsPre/Post`.

---
*Документ создан автоматически.*
