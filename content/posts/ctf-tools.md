---
title: "CTF Tools"
date: 2020-02-23T13:59:26Z
draft: false
disqus: false
---

This is going to be more of a long running list of tools that I have used while
doing CTFs. There's a good chance that I'll update/append to it as time goes
on. Possibly there'll also be the odd write up of specifics on how I use the
tool.

## Gobuster

Used for finding directory traversal on a web host.

 **Install**: 

```bash
go get github.com/OJ/gobuster
```

**Usage**:

```bash
curl -O https://raw.githubusercontent.com/digination/dirbuster-ng/master/wordlists/small.txt
gobuster dir -k -u http://$IP  -w small.txt
```

## Exploit Database

[Exploit-db](https://www.exploit-db.com/) is a great place for finding known exploitable vulnerabilities in software. Great if you know
which version of software something is running.

## Metasploit

If it's a known exploit, good chance that metasploit has a module to exploit it.

**Install**:

```bash
curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && \
  chmod 755 msfinstall && \
  ./msfinstall
```

**Usage**:

See the [quick start guide](https://metasploit.help.rapid7.com/docs).

## Upgrade to full shell with python

If you have a reverse shell, but it's a pain to use, and python is installed. Try this:

```python
python -c 'import pty; pty.spawn("/bin/bash")'
```

More exciting payloads can be found at https://github.com/swisskyrepo/PayloadsAllTheThings

## Other tools

Just a quick dump of general tools that I use all the time:

 * [Wireshark](https://www.wireshark.org/)
 * [GDB](https://www.gnu.org/software/gdb/)
 * [AFL](https://github.com/google/AFL)
