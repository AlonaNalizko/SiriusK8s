# лаба break linux chaos и break lab

здесь сделал весь блок учебных поломок linux и отработал диагностику как на мини инцидентах

1. подготовка

скопировал скрипты в папку лабы и выдал права на запуск

```bash
chmod +x linux-chaos.sh
chmod +x break_lab/*.sh
```

дальше запускал сценарии по одному, после каждого делал проверку и откат

2. сценарии linux chaos

```bash
sudo ./linux-chaos.sh --mode disk
sudo ./linux-chaos.sh --check
sudo ./linux-chaos.sh --restore

sudo ./linux-chaos.sh --mode network
sudo ./linux-chaos.sh --check
sudo ./linux-chaos.sh --restore

sudo ./linux-chaos.sh --mode process-cpu
sudo ./linux-chaos.sh --check
sudo ./linux-chaos.sh --restore

sudo ./linux-chaos.sh --mode memory
sudo ./linux-chaos.sh --check
sudo ./linux-chaos.sh --restore
```

на network режиме был жесткий стопор потому что ssh начал сыпаться. спасло то что заходил через консоль и руками проверил route и resolv.conf

3. сценарии break lab

```bash
cd break_lab
sudo bash 01_nginx_log_challenge.sh
sudo bash 02_network_break.sh
sudo bash 99_restore_network.sh
sudo bash 03_disk_break.sh
sudo bash 04_binary_break.sh
sudo bash 05_systemd_break.sh
sudo bash 99_restore_systemd.sh
```

тут самый интересный момент был с бинарями и systemd. сначала думал что сервис просто не стартует из за порта, а по факту были ограничения и кривой запускной скрипт

4. что использовал для диагностики

```bash
ip a
ip r
cat /etc/resolv.conf
cat /etc/nsswitch.conf
df -h
du -sh /* 2>/dev/null | sort -h
lsof | grep deleted
journalctl -xeu script-server.service
systemctl status script-server.service
chmod +x /opt/break_lab/*
ldd /opt/break_lab/*
```

после каждой поломки возвращал систему в норму и повторно прогонял проверки

5. вывод

эта лаба максимально жизненная. реально прокачал навык не паниковать, а идти по шагам: симптомы, диагностика, гипотеза, фикс, проверка, откат. теперь когда что то падает, уже не ловлю фриз и делаю все осознанно

скринов не будет, я на больничном и потратил оставшиеся силы на эту долбежку
