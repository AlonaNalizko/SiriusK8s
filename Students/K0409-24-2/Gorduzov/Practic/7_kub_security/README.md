# <b>СДЕЛАЛ?</b>
<b>ДА, сделал.</b>

* <b>RBAC (Role-Based Access Control)</b> <br>

    RBAC — это система контроля доступа в Kubernetes, которая определяет, кто и что может делать в кластере. Основные компоненты: ServiceAccount (учётная запись для пода), Role (правила внутри namespace), ClusterRole (правила на уровне всего кластера) и RoleBinding (привязка роли к аккаунту).

* <b>NetworkPolicy</b> <br>

    NetworkPolicy — это сетевой фаервол для подов. По умолчанию все поды в Kubernetes могут общаться со всеми, что небезопасно. NetworkPolicy ограничивает этот трафик. Политика применяется к подам через podSelector, может управлять входящим (Ingress) и исходящим (Egress) трафиком. Пустой список ingress означает запрет всего трафика. Разрешения задаются по меткам подов (podSelector), меткам namespace (namespaceSelector) или IP-диапазонам (ipBlock). Важно: NetworkPolicy требует CNI-плагин с поддержкой — Calico, Cilium или Weave; Flannel не поддерживает.

* <b>TLS и OpenSSL</b> <br>

    TLS обеспечивает шифрование трафика между клиентом и сервером. Для работы HTTPS в Kubernetes нужно выпустить сертификат. Процесс: сначала создаётся собственный центр сертификации (CA) — генерируются приватный ключ ca.key и корневой сертификат ca.crt. Затем для сервера создаются ключ webapp.key и запрос на подпись webapp.csr. CA подписывает этот запрос, выдавая сертификат webapp.crt. Сертификат должен включать расширение SAN (Subject Alternative Names) с указанием доменов и IP, для которых он действует. Готовый сертификат и ключ загружаются в Kubernetes как Secret типа tls, после чего Ingress использует этот Secret для обслуживания HTTPS.

* <b>Falco</b> <br>

    Falco — это система обнаружения вторжений (IDS) для Kubernetes, которая отслеживает системные вызовы в реальном времени. Она обнаруживает подозрительные действия: запуск оболочки в контейнере, чтение чувствительных файлов вроде /etc/shadow, неожиданные сетевые соединения и создание привилегированных контейнеров.
    
# <b>ПРОБЛЕМЫ</b>
нет проблем

# <b>SCREENШОТЫ</b>
![SCR1](https://github.com/noktirr/SCREENSHOTS/blob/main/7_kub_security/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2013-36-59.png) <br>
![SCR2](https://github.com/noktirr/SCREENSHOTS/blob/main/7_kub_security/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2013-41-01.png) <br>
![SCR3](https://github.com/noktirr/SCREENSHOTS/blob/main/7_kub_security/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2014-04-37.png) <br>
![SCR4](https://github.com/noktirr/SCREENSHOTS/blob/main/7_kub_security/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-30%2014-07-38.png) <br>