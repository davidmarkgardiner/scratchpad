# K9s: Kubernetes CLI To Manage Your Clusters In Style

![K9s Logo](https://k9scli.io/assets/k9s_small.png)

## What is K9s?

K9s is a terminal-based UI (TUI) to interact with your Kubernetes clusters. It provides a more intuitive and efficient way to navigate, observe, and manage your Kubernetes resources compared to traditional `kubectl` commands.

## Why K9s?

- **Speed**: Navigate between contexts, namespaces, and resources instantly
- **Simplicity**: Perform complex operations through simple keyboard shortcuts
- **Visibility**: Get a real-time view of your cluster health and resource usage
- **Productivity**: Avoid typing lengthy kubectl commands for common operations
- **Context Switching**: Switch between clusters without changing your global kubectl context

## Installation

Several installation methods are available:

### Using Package Managers

```bash
# Using Homebrew (macOS/Linux)
brew install k9s

# Using Chocolatey (Windows)
choco install k9s

# Using Scoop (Windows)
scoop install k9s

# Using Arch Linux
pacman -S k9s
```

### Using Arkade (Kubernetes Marketplace)

```bash
arkade get k9s
```

### Manual Install

Download the appropriate binary for your platform from the [releases page](https://github.com/derailed/k9s/releases).

## Basic Navigation

K9s provides an intuitive terminal interface with the following elements:

- **Top Header**: Shows cluster context, version, and resource stats
- **Main View**: Displays resources in a tabular format
- **Right Panel**: Common shortcut commands
- **Status Bar**: Shows breadcrumbs of your current location
- **Namespace Shortcuts**: Quick access to frequently visited namespaces

### Essential Shortcuts

| Shortcut | Action |
|----------|--------|
| `/` | Filter resources |
| `:` | Command mode (change resource view) |
| `Ctrl+A` | Show all available aliases |
| `?` or `Shift+?` | Show help with all available commands |
| `Esc` | Go back to previous view |
| `0-9` | Quick access to namespaces |

## Core Features

### 1. Resource Navigation

Enter command mode using `:` and type a resource name:

- `:pod` - View pods
- `:deploy` - View deployments
- `:svc` - View services
- `:ns` - View namespaces
- `:ctx` - View contexts

Autocomplete helps you find the right resource quickly.

### 2. Filtering

Use `/` to filter resources in any view:

- Simple text match: `/nginx`
- Filter by namespace: `/kube-system`
- Filter by status: `/Running`
- Filter by IP: `/192.168.`

### 3. Pod Management

Navigate to a pod and use:

- `l` - View logs
- `s` - Shell into container
- `d` - Describe pod
- `y` - View YAML
- `e` - Edit YAML
- `Ctrl+D` - Delete pod

### 4. Log Viewing

When viewing logs:

- `f` - Toggle full-screen mode
- `t` - Toggle timestamp display
- `0` - Show all logs (instead of tail)
- `w` - Toggle wrap text
- `>` or `<` - Navigate between containers in a pod

### 5. Port Forwarding

- Navigate to a pod or service
- Press `Shift+F`
- Enter local and container ports
- Access the forwarded port on your local machine

### 6. Deployment Management

Navigate to a deployment and use:

- `s` - Scale deployment (change replicas)
- `i` - Edit container image
- `e` - Edit deployment YAML
- `d` - Describe deployment

### 7. Context Switching

- `:ctx` to view available contexts
- Navigate to a context and press `Enter` to switch
- Global kubectl context remains unchanged

## Advanced Features

### 1. Vulnerability Scanning

Enable image scanning in your config to view vulnerability scores:

- Press `v` on a resource to see vulnerabilities
- The 5-bit vector indicates severity level
- Press `Enter` on a vulnerability to open in browser

### 2. Benchmarking

Use the built-in benchmarking tool:

- `:benchmark` to access
- Useful for testing cluster performance

### 3. Popeye Integration

K9s integrates with Popeye, a Kubernetes cluster sanitizer:

- `:popeye` to run the scanner
- Identifies potential issues in your cluster
- Provides detailed information on errors and warnings

## Customization

### Configuration

K9s stores its configuration in `~/.config/k9s/config.yml` (use `k9s info` to find location on your system).

Common configurations:

```yaml
k9s:
  # Enable/disable mouse mode
  enableMouse: true
  
  # Hide logo when true
  logoless: false
  
  # Hide icons when true
  noIcons: false
  
  # Specify custom skin
  skin: dracula
  
  # Enable image scans
  enableImageScan: true
```

### Skins/Themes

K9s supports custom color themes. The theme files are stored in `~/.config/k9s/skins`.

Popular themes include:
- Dracula
- Tokyo Night
- Monokai
- Nord

Find more skins in the [K9s GitHub repository](https://github.com/derailed/k9s/tree/master/skins).

### Custom Aliases

Define your own aliases in `~/.config/k9s/aliases.yml`:

```yaml
aliases:
  # Alias to show custom resources
  mk: mycustomresources
  # Alias for commonly used filters
  pp: /app=prometheus
```

## Tips and Tricks

1. Use `Shift+C` to sort resources by CPU usage
2. Use `Shift+M` to sort resources by memory usage
3. Run multiple K9s instances to monitor different clusters simultaneously
4. Use the `x` key to toggle header information
5. Use the `Ctrl+S` to save the current view to a file

## Limitations

- Not suitable for batch operations (use kubectl for those)
- Not designed for scripting
- For applying a directory of manifest files, kubectl is still preferred

## Resources

- [Official K9s Website](https://k9scli.io)
- [GitHub Repository](https://github.com/derailed/k9s)
- [Documentation](https://k9scli.io/topics/commands)

## License

K9s is licensed under the Apache License 2.0.