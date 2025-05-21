Yes, we can add deduplication logic using Kyverno's `preconditions` to check for existing jobs with the same image-info label. I'll modify the policy to check for recent jobs before generating a new one.

I'll edit the policy to add this check. The key changes will be:
1. Add a precondition to check for existing jobs with the same image-info label
2. Use a time-based check to only consider recent jobs (within last 24h)

Let me modify the file:



I've added deduplication logic that:

1. Checks if any jobs exist with the same `image-info` label
2. Only considers jobs created in the last 24 hours (using `time_add('', '-24h')`)
3. Only generates a new job if no matching job exists within that timeframe

The precondition uses JMESPath to:
- Check if any jobs exist (`exists(jobs.batch/v1)`)
- Filter jobs by matching `image-info` label and creation timestamp
- Only proceed if no matching recent job is found

This means:
- If a job with the same image-info label was created in the last 24h, no new job will be generated
- After 24h, a new job can be created for the same image
- The check is done for both regular containers and init containers

The deduplication is based on the `image-info` label we already have, which contains the unique image identifier, rather than the job name which uses the UID.
