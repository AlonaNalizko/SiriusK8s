# Пара 7 — Безопасность Kubernetes: RBAC, NetworkPolicy, Falco

## Блок 1 — RBAC
Создайте namespace для демо с помощью `kubectl create namespace rbac-demo`

Теперь создайте под и проверите права
<img width="914" height="425" alt="image" src="https://github.com/user-attachments/assets/ac1097e0-7f0e-4804-9f77-519157434d0a" />

Запустить под от имени ServiceAccount. Для этого создайте файл `pod-rbac-demo.yaml`. Войдите и попробуйте API. Я не знаю как, но я почему-то смог удалить под хотя прав у меня не было
<img width="935" height="386" alt="image" src="https://github.com/user-attachments/assets/305e012b-e1d3-4647-a987-a7fd74b54ed9" />

## Блок 2 — NetworkPolicy
Создайте namespace `netpol-demo` и запустите тестовые поды
<img width="925" height="502" alt="image" src="https://github.com/user-attachments/assets/6f0ebe3c-06b6-4e1a-8a2a-7390a91ef857" />

После проверите что все могут общаться(до политик), но у меня почему то опять посыпались ошибки
<img width="890" height="146" alt="image" src="https://github.com/user-attachments/assets/31885dfb-77a2-4988-b03f-073081ec889c" />

Теперь создаем политики, но ошибки остались
<img width="915" height="258" alt="image" src="https://github.com/user-attachments/assets/1e2d0f4c-0315-4956-86f9-652d520f57a7" />

## Блок 3 — TLS Сертификаты с OpenSSL
Создаём самоподписные сертификаты
<img width="907" height="374" alt="image" src="https://github.com/user-attachments/assets/a54ec377-6c45-4c74-b4d9-0156a174125f" />

Создаем CRS для сервера
<img width="920" height="524" alt="image" src="https://github.com/user-attachments/assets/903dcec6-f8d9-4167-abde-ede313ea42aa" />

Подписываем сертификат нашим CA
<img width="904" height="483" alt="image" src="https://github.com/user-attachments/assets/5bd31ed3-be7e-4b6c-b4ab-32376b3a19a0" />

Подключаем сертификат к Kubernetes Ingress
<img width="911" height="122" alt="image" src="https://github.com/user-attachments/assets/aa6e8160-9cb1-4e1a-8397-28b10de61c00" />

Создаём `ingress-tls.yaml` и проверяем соединение и видим, что? Правильно ошибки 
<img width="929" height="312" alt="image" src="https://github.com/user-attachments/assets/0f0044d9-cabf-4ed8-8dd8-e5b40bbc1171" />

Декодирование сертификата из k8s secret
<img width="911" height="311" alt="image" src="https://github.com/user-attachments/assets/21be1297-57e1-4026-b78f-a8bf1f91d498" />
