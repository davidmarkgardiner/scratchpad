feat(kyverno): add hostname mutation policies and tests

- Add mutation policies for VirtualService and HTTPRoute hostnames
- Create test cases for mutation behavior
- Update README with mutation policy documentation
- Add example resources showing hostname transformations

This extends the existing validation policies with automatic namespace
prefixing for both VirtualService hosts and HTTPRoute hostnames.