# NixOS Flake Configurations

This repository contains NixOS configurations for all my systems using Nix flakes.

## 🖥️ Systems

### akira (Home Server)
- **Hardware**: i7-4770, 16GB RAM
  - 16GB NVMe (system)
  - 512GB SSD (Docker/VMs at `/data`)
  - 6TB HDD (media storage)
- **Services**: Docker, Jellyfin, Samba, Tailscale
- **Special**: UPS monitoring with auto-hibernate

### loona (Laptop)
- **Hardware**: ThinkPad X13 2-in-1 Gen 5
  - AMD Radeon RX 7600 XT eGPU (Thunderbolt)
  - Quectel EM061K cellular modem
- **Desktop**: GNOME with Secure Boot (Lanzaboote)
- **Features**: Development environment, virtualization, gaming

### latte (Tablet)
- **Hardware**: Xiaomi Mi Pad 2
- **Desktop**: Phosh (mobile interface)
- **Purpose**: Personal media (AI-slop) consumption

## 📁 Repository Structure

```
.
├── flake.nix              # Main flake definition
├── flake.lock             # Locked dependency versions
├── common/                # Shared configuration
│   ├── configuration.nix  # Common settings
│   └── prelude.nix       # Helper functions
├── modules/               # Custom NixOS modules
│   ├── default.nix
│   └── quectel-modem-fix.nix  # Auto-fix for cellular modem
└── nodes/                 # Per-host configurations
    ├── akira/
    ├── loona/
    └── latte/
        ├── configuration.nix
        ├── hardware-configuration.nix
        └── host-metadata.nix
```

## 🚀 Usage

### Building Configurations

```bash
# Check flake validity
nix flake check

# Show available configurations
nix flake show

# Build a specific configuration (without deploying)
nix build .#nixosConfigurations.loona.config.system.build.toplevel
```

### Deploying Locally

From the host machine:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

Example for loona:
```bash
sudo nixos-rebuild switch --flake .#loona
```

### Remote Deployment

Deploy to another machine from loona (recommended since akira has limited storage):

```bash
# Deploy to akira
nixos-rebuild switch --flake .#akira --target-host root@akira --use-remote-sudo

# Deploy to latte
nixos-rebuild switch --flake .#latte --target-host gmglbn_0@latte --use-remote-sudo
```

### Testing Changes

Build without deploying:
```bash
nixos-rebuild build --flake .#<hostname>
```

Boot into a new configuration without switching:
```bash
sudo nixos-rebuild boot --flake .#<hostname>
```

## 📝 Adding a New Host

1. Create a new directory in `nodes/`:
   ```bash
   mkdir nodes/newhostname
   ```

2. Create `host-metadata.nix`:
   ```nix
   {
     arch = "x86_64-linux";  # or "aarch64-linux"
     host = "newhostname.local";
   }
   ```

3. Create `configuration.nix` with your host-specific settings

4. Generate hardware configuration on the target machine:
   ```bash
   nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```
   Then copy it to `nodes/newhostname/`

5. The flake will automatically discover and include it!

## 🔐 Secrets Management

Secrets are stored outside the repository in `/etc/nixos/secrets/`:

- **akira**: `/etc/nixos/secrets/ups-password` - UPS monitoring password

Create the secrets directory if it doesn't exist:
```bash
sudo mkdir -p /etc/nixos/secrets
sudo chmod 700 /etc/nixos/secrets
```

## 🛠️ Troubleshooting

### Secure Boot (loona)

If you need to enroll keys for Lanzaboote:
```bash
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft
```

### Quectel Modem (loona)

The modem should work automatically via the `quectel-modem-fix` module. If not, check:
```bash
sudo systemctl status quectel-modem-fix
sudo journalctl -u quectel-modem-fix
```

### Build Failures

Clear the nix store and rebuild:
```bash
nix-collect-garbage -d
sudo nixos-rebuild switch --flake .#<hostname>
```

Update flake inputs:
```bash
nix flake update
```

## 🔄 Development

Enter a dev shell with nix tools:
```bash
nix develop
```

This provides:
- `nixpkgs-fmt` - Format nix files
- `nil` - Nix LSP for editors
- `git`

Format all nix files:
```bash
find . -name '*.nix' -exec nixpkgs-fmt {} \;
```

## 📚 Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [nixos-hardware](https://github.com/NixOS/nixos-hardware)
- [Lanzaboote](https://github.com/nix-community/lanzaboote)
