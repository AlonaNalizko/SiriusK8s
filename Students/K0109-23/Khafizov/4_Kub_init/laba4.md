# Пара 4 — Kubernetes: установка кластера, первые поды

## Блок 1 - Состояние кластера
Узнаем какие ноды есть на хосте
<img width="945" height="103" alt="image" src="https://github.com/user-attachments/assets/249120d4-b917-4a16-b1de-b175364db2a4" />

Узнаем список подов в kube-config и статус основных компонентов
<img width="899" height="327" alt="image" src="https://github.com/user-attachments/assets/10f9dd9d-3aef-481e-9559-c080f49abefe" />

**Вопрос:** Какие поды в `kube-system` всегда должны быть Running?
**Ответ:** 
- coredns-...
- local-path-provisioner-...
- metrics-server-...
- svclb-traefik-...
- traefik-...

## Блок 2 - Первый Pod
Запустим под императивно
<img width="912" height="54" alt="image" src="https://github.com/user-attachments/assets/fa8d64c7-ee2e-4ff1-9cd3-2c94118da448" />

Войдем в него и узнаем о нем инфу
<img width="885" height="850" alt="image" src="https://github.com/user-attachments/assets/5aadbd9a-46c7-4075-b7d9-1e4fe55484c3" />

## Блок 3 - Pod через YAML
Создадим файл `pod.yaml` и применим его `kubectl apply -f pod.yaml`
После посмотрим оба контейнера в поде
<img width="892" height="64" alt="image" src="https://github.com/user-attachments/assets/5739a6ec-c77b-439f-98de-696b8c025550" />

Убедимся, что можем узнать YAML запущенного пода
<img width="938" height="785" alt="image" src="https://github.com/user-attachments/assets/26041147-ab1b-41ba-afb9-6edd5d031696" />

## Блок 4 - Самовосстановление
Убьем основной процесс nginx - k8s должен перезапуститься
<img width="917" height="278" alt="image" src="https://github.com/user-attachments/assets/bbdc63b1-794a-4658-a30b-9aa63e0a02e4" />

**Вопрос:** Почему Pod не удалился, а перезапустился? Кто за это отвечает?
**Ответ:** После завершения процесса Nginx `Kubelet` автоматически перезапустил контейнер согласно политике `restartPolicy: Always`. Pod восстановился: оба контейнера снова работают (READY: 2/2), зафиксирован один перезапуск (RESTARTS: 1).
