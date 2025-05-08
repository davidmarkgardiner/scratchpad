I'll provide you with alternative ways to write a Kyverno policy that only applies to images starting with "my.registry.com/" while excluding others like "test.my.registry.com".

Here's a better approach using the `startsWith` function:

```yaml
preconditions:
  all:
  - key: "{{ startsWith(request.object.spec.containers[0].image, 'my.registry.com/') }}"
    operator: Equals
    value: true
```

This directly checks if the container image path starts with exactly "my.registry.com/" which will match "my.registry.com/image" but not "test.my.registry.com/image".

Another alternative using regex pattern matching:

```yaml
preconditions:
  all:
  - key: "{{ regex_match('^my\\.registry\\.com/', request.object.spec.containers[0].image) }}"
    operator: Equals
    value: true
```

This uses a regex pattern to match only strings that start with exactly "my.registry.com/" at the beginning (the ^ anchor ensures it's at the start of the string).

If you need to check across multiple containers, you could use:

```yaml
preconditions:
  all:
  - key: "{{ any(request.object.spec.containers[*].image, '@', startsWith(@, 'my.registry.com/')) }}"
    operator: Equals
    value: true
```

Would you like me to explain any of these approaches in more detail?