
check required rbac
apply rbac
deploy policy

make dummy deployment
test job is created

we must use image name to create the job name this is so job only run once per image

create scripts to clean up and run porcess again so we can verify it works e2e
adjust the policy as needed

it needs to be unique per image name and tag

can we use md5sum or base64 etc to make some value from the intial image name

we will have muliple jobs running per request.object.metadata.name so this might miss cone containers 

use k get crd | grep -i kyverno
and explain the crd to get more info

also use contect7 if needed

add to mcp.json

{
  "projects": {
    "/path/to/your/project": {
      "mcpServers": {
        "Context7": {
          "command": "npx",
          "args": ["-y", "@upstash/context7-mcp"]
        }
      }
    }
  }
}