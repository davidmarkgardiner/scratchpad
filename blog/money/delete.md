Here's the updated version that clarifies the deletion requirement:

---

**Subject: Important Update: Cluster Management Policy Changes**

Team,

We need to implement more efficient cluster management practices immediately. Currently, we're running between 14-20 clusters, but our usage data shows they're only active for approximately 4-5 hours total per day, with minimal weekend utilization. This represents a significant inefficiency in our resource allocation.

**New Policy Effective Immediately:**

With Node Auto Provisioner (NAP) in place, we can no longer stop/start clusters—they must be completely deleted when not in use. Therefore, we'll be implementing automatic cluster deletion daily at **8:00 PM**.

**Key Changes:**

- **Daily Deletion**: All clusters will be automatically deleted at 8:00 PM each evening (not just stopped)
- **Resource Locks**: If you need to keep a cluster running overnight (for stress testing or critical operations), you can apply a resource lock to prevent deletion. Please note this should be the exception, not the rule—avoid using locks simply to preserve work that could be saved in a manifest for next-day deployment
- **Morning Provisioning**: We'll provision three shared clusters each morning (DO1, DO2, DO3) for immediate use
- **Additional Clusters**: If you need a dedicated cluster beyond the shared ones, you'll need to provision it yourself each day
- **Save Your Work**: Since clusters will be deleted completely, ensure all your work is saved in manifests or other persistent storage before 8:00 PM

**Next Steps:**

We'll maintain the current numbered cluster approach for now and monitor how well this system works. If we continue to experience resource conflicts, we'll transition to an initial-based naming system instead of numbers.

This change will help us optimize our infrastructure costs while maintaining the flexibility everyone needs to do their work effectively. Please reach out if you have questions or concerns about this new process.

Thanks for your cooperation in making our cluster management more sustainable.

---

The key updates highlight that clusters will be completely deleted (not just shut down) due to NAP limitations, emphasizing the importance of saving work externally.