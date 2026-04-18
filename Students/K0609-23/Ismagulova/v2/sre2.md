# Отчёт по лабораторной работе: Docker (безопасность), Multi-stage Docker Build

## Цель работы

Освоить принципы безопасной контейнеризации с использованием multi-stage Docker-сборки

### Урок 2. Docker (безопасность)

#### 2.1. Проверка безопасности контейнера

Для анализа уровня безопасности контейнера использовался скрипт `check-docker-security.sh`, который проверяет следующие параметры:

- **Capabilities** – минимально необходимые возможности Linux
- **Запуск от root** – не рекомендуется
- **Privileged mode** – запрещён
- **Права на файловую систему** – ограничены
- **Сетевой режим** – по умолчанию (bridge)

Для использования данного скрипта созданы для каждого контейнера соответствующие пользователи, что позволило выполнить тест.

<img width="1037" height="594" alt="Вставленное изображение (8)" src="https://github.com/user-attachments/assets/e01cbd91-5645-4cb4-b5fc-6b8d633f28a5" />

<img width="1348" height="726" alt="Снимок экрана от 2026-04-18 19-41-02" src="https://github.com/user-attachments/assets/3fed3726-7fac-4c05-afca-793fdd0ea66c" />

<img width="624" height="459" alt="Вставленное изображение (10)" src="https://github.com/user-attachments/assets/a7efe6fd-1dc5-4cb3-9bbc-d241649242d2" />

---

#### 2.2. Multi-stage Docker Build

В рамках второй части урока была изучена и применена multi-stage сборка, описанная в файле `docker/Dockerfile`.

##### Структура сборки:

| Этап | Назначение |
|------|------------|
| Stage 1 (builder) | Компиляция приложения, установка зависимостей |
| Stage 2 (runtime) | Только бинарный файл и минимальное окружение |

<img width="802" height="501" alt="изображение" src="https://github.com/user-attachments/assets/9ddcba10-28d0-420d-9668-7da9ec07c825" />


##### Результат оптимизации:

| Параметр | До multi-stage | После multi-stage |
|----------|----------------|--------------------|
| Размер образа | ~500 MB | **< 50 MB** |


<img width="1715" height="345" alt="Вставленное изображение (11)" src="https://github.com/user-attachments/assets/4f25e60a-df00-4d50-af92-f85dbcdbe259" />

<img width="1705" height="565" alt="Вставленное изображение (12)" src="https://github.com/user-attachments/assets/f76174a9-6995-40f7-a246-a18e3402808f" />

##### Команда для сборки:

```bash
docker build -t app . --target runtime
```

---
## Ошибки
Из ошибок стоит отметить большой объем исправлений файла docker-compose.yml.
