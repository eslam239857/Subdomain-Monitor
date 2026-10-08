# 🔎 Subdomain Monitor & Discord Alert

Lightweight Bash automation for monitoring authorized domains, discovering new subdomains, checking live hosts, and sending Discord alerts.

## 🚀 Features

* 🔍 Subdomain enumeration with **Subfinder**
* 🆕 Detects new subdomains
* 🌐 Live/Not Live detection with **httpx**
* 🔔 Discord notifications
* 💾 Maintains subdomain history
* ⚠️ Validates `httpx` success before marking hosts as dead
* ⚡ Simple and lightweight

## 🛠️ Requirements

```bash
subfinder
httpx
curl
python3
```

## 🔄 Workflow

```text
Domains
   ↓
Subfinder
   ↓
Compare History
   ↓
New Subdomains
   ↓
httpx
   ↓
Live / Not Live
   ↓
Discord Alert
   ↓
Update History
```

## ▶️ Usage

```bash
chmod +x monitor.sh
export DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK"
./monitor.sh
```

### 📁 Files

```text
monitor.sh
domain.txt
subdomains_old.txt
README.md
```

## 🎯 Use Cases

* 🐞 Bug bounty reconnaissance
* 🔐 Authorized penetration testing
* 🌐 Attack-surface monitoring
* 🤖 Recon automation

## 🔐 Security

Never commit your Discord Webhook to GitHub. Use an environment variable and regenerate the webhook if it is exposed.

## ⚠️ Legal

Use only against domains you own or are explicitly authorized to test.
