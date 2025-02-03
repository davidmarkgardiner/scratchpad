
1. First, update your WSL package list:
```bash
sudo apt update
```

2. Install prerequisites:
```bash
sudo apt install wget git build-essential -y
```

3. Download the latest Go (as of January 2025, version 1.22.x). You can get it directly from Go's website:
```bash
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
```

4. Remove any previous Go installation and extract the new one:
```bash
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
```

5. Set up the Go environment by adding these lines to your `~/.bashrc` or `~/.profile`:
```bash
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
```

6. Apply the changes:
```bash
source ~/.bashrc
```

7. Verify the installation:
```bash
go version
```

You should see something like `go version go1.22.0 linux/amd64`

To test your installation further, you can create a simple program:

```bash
mkdir -p ~/go/src/hello
cd ~/go/src/hello
```

Create a file named `hello.go`:
```go
package main

import "fmt"

func main() {
    fmt.Println("Hello, WSL!")
}
```

Then run it:
```bash
go run hello.go
```

Would you like me to explain any of these steps in more detail?
