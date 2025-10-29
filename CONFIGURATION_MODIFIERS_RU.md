# Краткая справка: система Autowirable DI и модификаторы wiring

Этот проект использует систему Dependency Injection (DI) основанную на `StdConfig` у Foundry для:
1. Подключения конфигурации окружения (debug / production).
2. Автоматического развёртывания и связывания контрактов через модификаторы `autowire`, `proxywire`, `configwire`.
3. Детерминированного вычисления адресов контрактов через `Sources.Source`.
4. Получения адресов развёрнутых контрактов через функции `autowired()`.

---
## 1. Базовый класс `Autowirable`
Все скрипты развёртывания наследуются от `Autowirable`, который предоставляет:
- Автоматическую настройку системы wiring
- Модификаторы для связывания контрактов
- Функции для получения адресов развёрнутых контрактов

Конфигурация загружается автоматически (по умолчанию DEBUG режим) при создании `Autowirable`.

### Когда применять
Наследуйтесь от `Autowirable` во всех скриптах развёртывания:

### Пример
```solidity
contract MyDeployScript is Autowirable {
    function run() public { /* ... */ }
}
```

---
## 2. Источники (`Sources.Source`)
`Sources.Source` — enum, где каждая позиция соответствует определяемому в проекте контракту / типу деплоя. У источников есть вспомогательные методы (например, `toSalt()`, `toString()`), которые используются для детерминированного адреса через CREATE2 и для идентификации в конфигурации.

---
## 3. Модификаторы wiring

### `autowire(Sources.Source source)`
Развёртывает контракт напрямую с детерминированным адресом.

### `proxywire(Sources.Source source)`
Развёртывает прокси (TransparentUpgradeableProxy) для данного источника.

### `configwire(IConfiguration configContract)`
Выполняет конфигурационный контракт, который может развернуть несколько связанных контрактов.

### `accountwire(string memory nickname)`
Развёртывает именованный аккаунт (ModularSmartAccount) с указанным nickname.

### `nickwire(Sources.Source source, ShortString nickname)`
Развёртывает контракт с указанным nickname для возможности создания нескольких экземпляров.

### Для чего
Автоматизирует процесс развёртывания контрактов и сохранения их адресов в конфигурации для последующего использования.

### Пример (из `SSO.s.sol`)
```solidity
function run()
    public
    proxywire(Sources.Source.EOAKeyValidator)
    proxywire(Sources.Source.SessionKeyValidator)
    proxywire(Sources.Source.WebAuthnValidator)
    configwire(guardianExecutorConfig)
    configwire(xsollaRecoveryConfig)
    configwire(eip4337FactoryConfig)
    accountwire(ALICE_SMART_ACC)
{
    // В теле функции контракты уже развёрнуты и доступны через autowired()
}
```

---
## 4. Функции `autowired()`

### `autowired(Sources.Source source)`
Получает адрес контракта, развёрнутого через `autowire`.

### `autowired(Sources.Source source, string memory nickname)`
Получает адрес контракта с указанным nickname (для прокси или именованных аккаунтов).

### Примеры использования
```solidity
// Получение адреса обычного контракта
address beacon = autowired(Sources.Source.UpgradeableBeacon);

// Получение адреса прокси для конкретного модуля
address eoaValidator = autowired(
    Sources.Source.TransparentUpgradeableProxy, 
    Sources.Source.EOAKeyValidator.toString()
);

// Получение адреса именованного аккаунта
address aliceAccount = autowired(Sources.Source.ModularSmartAccount, ALICE_SMART_ACC);
```

---
## 5. Конфигурационные контракты
Для сложных развёртываний создаются специальные конфигурационные контракты, реализующие интерфейс `IConfiguration`. Они позволяют группировать связанные развёртывания.

### Примеры:
- `Eip4337FactoryConfiguration` — развёртывает EIP-4337 фабрику и связанные компоненты
- `GuardianExecutorConfiguration` — развёртывает Guardian Executor и его прокси
- `GuardianBasedRecoveryExecutorConfiguration` — развёртывает Recovery Executor

### Использование в скрипте:
```solidity
function setUp() public {
    eip4337FactoryConfig = new Eip4337FactoryConfiguration(vm, wiringMechanism, msg.sender);
    guardianExecutorConfig = new GuardianExecutorConfiguration(vm, wiringMechanism, msg.sender);
}

function run() public configwire(eip4337FactoryConfig) configwire(guardianExecutorConfig) {
    // Конфигурации выполняются автоматически
}
```

---
## 6. Типичная структура модификаторов
Рекомендуемый порядок в `run()` / `deploy*()` функциях:
1. Модификаторы wiring (`autowire`, `proxywire`, `configwire`, `accountwire`, `nickwire`)
2. Внутри тела: использование `autowired()` для получения адресов развёрнутых контрактов
3. (Опционально) логирование через `console.log`

---
## 7. Краткие советы
- Используйте `proxywire` для модулей, которые должны быть обновляемыми через прокси
- Используйте `autowire` для простых контрактов, которые не требуют прокси
- Используйте `configwire` для группировки связанных развёртываний в конфигурационные контракты
- Используйте `accountwire` для создания именованных аккаунтов с уникальными nickname
- Используйте `nickwire` когда нужно создать несколько экземпляров одного типа контракта
- Получайте адреса через `autowired()` только после объявления соответствующих модификаторов

---
## 8. Минимальные примеры

### Простое развёртывание контракта
```solidity
contract SimpleScript is Autowirable {
    function run() public autowire(Sources.Source.EOAKeyValidator) {
        address validator = autowired(Sources.Source.EOAKeyValidator);
        console.log("EOAKeyValidator deployed at:", validator);
    }
}
```

### Развёртывание прокси
```solidity
contract ProxyScript is Autowirable {
    function run() public proxywire(Sources.Source.SessionKeyValidator) {
        address proxy = autowired(
            Sources.Source.TransparentUpgradeableProxy,
            Sources.Source.SessionKeyValidator.toString()
        );
        console.log("SessionKeyValidator proxy deployed at:", proxy);
    }
}
```

### Полный пример с конфигурацией
```solidity
contract FullScript is Autowirable {
    GuardianExecutorConfiguration private guardianConfig;
    
    function setUp() public {
        guardianConfig = new GuardianExecutorConfiguration(vm, wiringMechanism, msg.sender);
    }
    
    function run() 
        public 
        proxywire(Sources.Source.EOAKeyValidator)
        configwire(guardianConfig)
        accountwire("TestAccount")
    {
        address eoaProxy = autowired(
            Sources.Source.TransparentUpgradeableProxy,
            Sources.Source.EOAKeyValidator.toString()
        );
        address guardianProxy = autowired(
            Sources.Source.TransparentUpgradeableProxy,
            Sources.Source.GuardianExecutor.toString()
        );
        address account = autowired(Sources.Source.ModularSmartAccount, "TestAccount");
        
        console.log("EOA Validator:", eoaProxy);
        console.log("Guardian Executor:", guardianProxy);
        console.log("Test Account:", account);
    }
}
```

---
## 9. Запуск скриптов (пример)
(Замените RPC на нужный.)
```bash
forge script script/xsolla/SSO.s.sol:SSO --rpc-url $RPC --broadcast -vvvv
```
Для dry-run можно убрать `--broadcast`.

---
## 10. Возможные ошибки
- `ChooseConfigurationFirst()` — конфигурация не была загружена (обычно автоматически обрабатывается в `Autowirable`)
- Ошибки при вызове `autowired()` — убедитесь, что соответствующий модификатор wiring был применён
- Неверные nickname — убедитесь, что используете правильные строковые идентификаторы для прокси и аккаунтов

---
## 11. Резюме
| Модификатор/Функция | Назначение | Когда использовать |
|---------------------|------------|--------------------|
| `autowire` | Развёртывает контракт напрямую | Для простых контрактов без прокси |
| `proxywire` | Развёртывает прокси для контракта | Для обновляемых модулей |
| `configwire` | Выполняет конфигурационный контракт | Для группировки связанных развёртываний |
| `accountwire` | Развёртывает именованный аккаунт | Для создания ModularSmartAccount |
| `nickwire` | Развёртывает контракт с nickname | Для нескольких экземпляров одного типа |
| `autowired` | Получает адрес развёрнутого контракта | Для доступа к адресам после развёртывания |

Если потребуется расширенная документация — можно углубить разделы про создание конфигурационных контрактов и внутреннюю реализацию wiring mechanism.
