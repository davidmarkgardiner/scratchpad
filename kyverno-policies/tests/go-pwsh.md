I'll help you install Go on PowerShell. Here's how:

1. Download Go for Windows using PowerShell:
```powershell
$version = "1.22.0"
$url = "https://go.dev/dl/go${version}.windows-amd64.zip"
$output = "$env:TEMP\go${version}.windows-amd64.zip"
Invoke-WebRequest -Uri $url -OutFile $output
```

2. Extract Go to C:\Program Files:
```powershell
Expand-Archive -Path $output -DestinationPath "C:\Program Files" -Force
```

3. Set up environment variables:
```powershell
# Set system environment variables
[Environment]::SetEnvironmentVariable("GOROOT", "C:\Program Files\go", "Machine")
[Environment]::SetEnvironmentVariable("GOPATH", "$env:USERPROFILE\go", "User")
[Environment]::SetEnvironmentVariable("Path", "$env:Path;C:\Program Files\go\bin;$env:USERPROFILE\go\bin", "Machine")
```

4. Create Go workspace directories:
```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\go\src" -Force
New-Item -ItemType Directory -Path "$env:USERPROFILE\go\bin" -Force
New-Item -ItemType Directory -Path "$env:USERPROFILE\go\pkg" -Force
```

5. Verify the installation:
```powershell
# Refresh environment variables in current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Check Go version
go version
```

6. Test the installation with a simple program:
```powershell
# Create a test directory
New-Item -ItemType Directory -Path "$env:USERPROFILE\go\src\hello" -Force
Set-Location "$env:USERPROFILE\go\src\hello"

# Create hello.go
@"
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}
"@ | Out-File -FilePath "hello.go" -Encoding UTF8

# Run the program
go run hello.go
```

You'll need to restart your PowerShell session for the environment variables to take effect. Would you like me to explain any of these steps in more detail?
