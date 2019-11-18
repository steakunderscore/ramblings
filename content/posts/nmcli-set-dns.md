---
title: "nmcli Set DNS"
date: 2019-11-17T11:39:54Z
draft: false
disqus: false
---

Setting the DNS of my current wifi to Google's DNS servers. Mostly taken from [serverfault](https://serverfault.com/a/810639/169530).

```bash
WIFI_CON=$(nmcli device status | grep wifi | head -n 1 | sed 's/^[[:alnum:]]\+ \+wifi \+[[:alnum:]]\+  \+//')
nmcli connection modify "${WIFI_CON}" ipv4.dns "8.8.8.8 8.8.4.4"
nmcli connection modify "${WIFI_CON}" ipv6.dns "2001:4860:4860::8888 2001:4860:4860::8844"
nmcli connection modify "${WIFI_CON}" ipv4.ignore-auto-dns yes
nmcli connection modify "${WIFI_CON}" ipv6.ignore-auto-dns yes
nmcli connection down "${WIFI_CON}"
nmcli connection up "${WIFI_CON}"
```

To check that everything has been correctly set
```bash
cat /etc/resolv.conf
```
