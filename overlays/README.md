# Overlay Ports for WSE Customizations

This folder contains project-specific port overrides to keep upstream `vcpkg` merges clean.

## Included custom ports

- `cgal`
- `ceres`
- `opencv4`
- `glog`
- `gdal`

## Usage

Use this overlay when running `vcpkg`:

```powershell
.\vcpkg install <port> --overlay-ports=.\overlays\ports
```

Or set an environment variable:

```powershell
$env:VCPKG_OVERLAY_PORTS = (Resolve-Path .\overlays\ports)
.\vcpkg install <port>
```

## Recommended workflow

1. Keep upstream `ports/` unchanged where possible.
2. Apply your customizations in `overlays/ports/<port>/`.
3. Periodically diff each overlay port against upstream and rebase the overlay as needed.
