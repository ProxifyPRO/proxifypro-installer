<div align="center">

# ProxifyPRO Installer

**Self-hosted 4G mobile proxy manager. One command. Zero configuration.**

[Website](https://proxifypro.com) · [Documentation](https://proxifypro.com#features) · [Get License](https://proxifypro.com#pricing)

</div>

---

## Quick Install

### Linux (Ubuntu / Debian)

```bash
curl -fsSL https://proxifypro.com/install.sh | sudo bash
```

### macOS (Intel + Apple Silicon)

```bash
curl -fsSL https://proxifypro.com/install-macos.sh | bash
```

### Windows 10 / 11 (PowerShell as Administrator)

```powershell
iwr -useb https://proxifypro.com/install-windows.ps1 | iex
```

---

## What you get

After installation completes:

- ✓ Dashboard at `http://localhost:3000`
- ✓ Auto-detection of 4G dongles (Huawei E3372 HiLink, ZTE, etc)
- ✓ HTTPS + SOCKS5 proxies per dongle
- ✓ License-protected (BYO key)
- ✓ systemd / launchd / Windows Service integration

---

## Requirements

- **OS**: Ubuntu 20.04+ / Debian 11+ / macOS 12+ / Windows 10/11
- **Architecture**: x86_64 (Linux/Windows), Intel or Apple Silicon (macOS)
- **Node.js**: v22 LTS (the installer will check and prompt if missing)
- **License**: Required. Get yours at [proxifypro.com](https://proxifypro.com)
- **Hardware**: At least one Huawei E3372 HiLink dongle (or compatible)

---

## CLI Commands

After installation, use the `proxifypro` command:

```bash
proxifypro start      # Start the service
proxifypro stop       # Stop the service
proxifypro restart    # Restart the service
proxifypro status     # Check service status
proxifypro logs       # Tail logs in real-time
proxifypro errors     # Tail error logs
proxifypro open       # Open dashboard in browser
proxifypro update     # Update to latest version
proxifypro uninstall  # Remove ProxifyPRO
```

---

## Supported Hardware

- Huawei E3372 HiLink (recommended)
- Huawei E3531
- ZTE MF833V
- Other HiLink-compatible USB dongles

See [Hardware Guide](https://proxifypro.com#hardware) for the complete list.

---

## Security

- License validation via [Keygen.sh](https://keygen.sh) (fingerprint-bound)
- Code integrity checks at every startup
- Bytecode-compiled production builds
- Offline grace period: 7 days
- Heartbeat: every 30 minutes

---

## Support

- 🌐 Website: [proxifypro.com](https://proxifypro.com)
- 📧 Issues: [GitHub Issues](https://github.com/ProxifyPRO/proxifypro-installer/issues)

---

<div align="center">

Made with ◇ by the ProxifyPRO team

</div>
