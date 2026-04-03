# СДЕЛАЛ?
ДА, сделал. В общем всё понятно.

*Блок 1 — Почему образ такой большой?*
Т.к. использовался полный образ python:3.12, который весит 900 МБ и содержит много лишнего. Плюс я скопировал все файлы командой COPY . ., и при установке пакетов через pip install в образ попал кэш, который тож занимает место.

*Блок 2 — Как multistage build помогает уменьшить размер образа?*
Multistage build позволяет разделить процесс на два этапа. На первом этапе ставятся зависимости в полном образе, где есть всё необходимое для сборки. А на втором этапе берётся легковесный образ на alpine, который весит 50 МБ, и копируется в него только уже установленные библиотеки и сам код.

*Блок 3 — Что показывают команды docker history и docker inspect?*
docker history показывает все слои образа. docker inspect выдает полную JSON-информацию об образе.

*Блок 4 — Для чего нужны команды docker tag и docker push?*
docker tag — для присвоения нового тега [registry]/[username]/[repository]:[tag]. docker push — выполняет загрузку образа

# ПРОБЛЕМЫ
без проблем.

# SCREENШОТЫ
![SCR1](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2013-57-46.png)
![SCR2](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2014-06-48.png)
![SCR3](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2014-11-10.png)
![SCR4](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2014-13-21.png)
![SCR5](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2014-14-02.png)
![SCR6](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2014-14-22.png)
![SCR7](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2014-14-41.png)
![SCR8](https://github.com/noktirr/SCREENSHOTS/blob/main/2_Docker_run/%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA%20%D1%8D%D0%BA%D1%80%D0%B0%D0%BD%D0%B0%20%D0%BE%D1%82%202026-03-25%2014-33-34.png)