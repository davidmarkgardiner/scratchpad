```
apiVersion: containerservice.azure.com/v1api20240901
kind: MaintenanceConfiguration
metadata:
  name: aksmanagedautoupgradeschedule-matrix
  namespace: default
spec:
  owner:
    name: sample-managedcluster-20240901
  
  # Primary maintenance window
  maintenanceWindow:
    schedule:
      weekly:
        dayOfWeek: Saturday
        intervalWeeks: 2  # Every other Saturday
    durationHours: 8
    startTime: 02:00
  
  # Multiple time-in-week slots for different types of maintenance
  timeInWeek:
    # Weekend maintenance windows
    - day: Saturday
      hourSlots:
        - 2
        - 3
        - 4
        - 5
        - 6
        - 7
        - 8
        - 9
    - day: Sunday
      hourSlots:
        - 1
        - 2
        - 3
        - 4
        - 5
  
  # Define periods when maintenance is NOT allowed
  notAllowedTime:
    # Block maintenance during business hours on weekdays
    - start: "2024-01-01T08:00:00Z"
      end: "2024-12-31T18:00:00Z"
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Weekly
        daysOfWeek:
          - Monday
          - Tuesday
          - Wednesday
          - Thursday
          - Friday
    
    # Block maintenance during holiday periods
    - start: "2024-12-20T00:00:00Z"
      end: "2024-12-31T23:59:59Z"
      timeZone: "UTC"
    
    # Block maintenance during critical business periods
    - start: "2024-03-01T00:00:00Z"
      end: "2024-03-31T23:59:59Z"
      timeZone: "UTC"
    
    # Block maintenance during summer peak hours
    - start: "2024-06-01T12:00:00Z"
      end: "2024-08-31T16:00:00Z"
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Daily

---
apiVersion: containerservice.azure.com/v1api20240901
kind: MaintenanceConfiguration
metadata:
  name: aksmanagedautoupgradeschedule-complex-matrix
  namespace: default
spec:
  owner:
    name: sample-managedcluster-20240901
  
  # Alternative: Multiple maintenance configurations for different scenarios
  timeInWeek:
    # Low-impact maintenance: Multiple small windows throughout the week
    - day: Monday
      hourSlots: [2, 3]  # 2-4 AM Monday
    - day: Tuesday
      hourSlots: [2, 3]  # 2-4 AM Tuesday
    - day: Wednesday
      hourSlots: [2, 3]  # 2-4 AM Wednesday
    - day: Thursday
      hourSlots: [2, 3]  # 2-4 AM Thursday
    - day: Friday
      hourSlots: [2, 3]  # 2-4 AM Friday
    
    # High-impact maintenance: Longer weekend windows
    - day: Saturday
      hourSlots: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  # 1-11 AM Saturday
    - day: Sunday
      hourSlots: [1, 2, 3, 4, 5, 6]  # 1-7 AM Sunday
  
  # Complex exclusion matrix
  notAllowedTime:
    # Business hours exclusion matrix (9 AM - 6 PM, Mon-Fri)
    - start: "2024-01-01T09:00:00Z"
      end: "2024-01-01T18:00:00Z"
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Weekly
        daysOfWeek: [Monday, Tuesday, Wednesday, Thursday, Friday]
    
    # Peak traffic hours exclusion (6 PM - 10 PM daily)
    - start: "2024-01-01T18:00:00Z"
      end: "2024-01-01T22:00:00Z"
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Daily
    
    # Monthly maintenance blackout (first week of each month)
    - start: "2024-01-01T00:00:00Z"
      end: "2024-01-07T23:59:59Z"
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Monthly
        weekOfMonth: 1
    
    # Quarterly business review periods
    - start: "2024-03-25T00:00:00Z"
      end: "2024-04-05T23:59:59Z"
      timeZone: "UTC"
    - start: "2024-06-25T00:00:00Z"
      end: "2024-07-05T23:59:59Z"
      timeZone: "UTC"
    - start: "2024-09-25T00:00:00Z"
      end: "2024-10-05T23:59:59Z"
      timeZone: "UTC"
    - start: "2024-12-20T00:00:00Z"
      end: "2025-01-05T23:59:59Z"
      timeZone: "UTC"

---
apiVersion: containerservice.azure.com/v1api20240901
kind: MaintenanceConfiguration
metadata:
  name: aksmanagedautoupgradeschedule-multi-region-matrix
  namespace: default
spec:
  owner:
    name: sample-managedcluster-20240901
  
  # Multi-region aware maintenance matrix
  timeInWeek:
    # Region 1: US East Coast (UTC-5) - Early morning maintenance
    - day: Sunday
      hourSlots: [9, 10, 11, 12]  # 4-8 AM EST
    
    # Region 2: US West Coast (UTC-8) - Early morning maintenance  
    - day: Sunday
      hourSlots: [12, 13, 14, 15]  # 4-8 AM PST
    
    # Region 3: Europe (UTC+1) - Early morning maintenance
    - day: Sunday
      hourSlots: [5, 6, 7, 8]  # 6-10 AM CET
    
    # Region 4: Asia Pacific (UTC+8) - Early morning maintenance
    - day: Saturday
      hourSlots: [22, 23, 0, 1]  # 6-10 AM AWST (spans midnight UTC)
  
  # Global exclusion patterns
  notAllowedTime:
    # Global business hours protection
    - start: "2024-01-01T14:00:00Z"  # 9 AM EST
      end: "2024-01-01T23:00:00Z"   # 6 PM EST
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Weekly
        daysOfWeek: [Monday, Tuesday, Wednesday, Thursday, Friday]
    
    # Asia Pacific business hours
    - start: "2024-01-01T01:00:00Z"  # 9 AM JST
      end: "2024-01-01T10:00:00Z"   # 6 PM JST
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Weekly
        daysOfWeek: [Monday, Tuesday, Wednesday, Thursday, Friday]
    
    # European business hours
    - start: "2024-01-01T08:00:00Z"  # 9 AM CET
      end: "2024-01-01T17:00:00Z"   # 6 PM CET
      timeZone: "UTC"
      recurringTimePattern:
        pattern: Weekly
        daysOfWeek: [Monday, Tuesday, Wednesday, Thursday, Friday]
```

Looking at the schema you provided, I can see that the `MaintenanceConfiguration` supports different scheduling patterns. While your example shows a weekly schedule, here's an example of a more complex matrix-style configuration that demonstrates multiple maintenance windows and constraints:This matrix configuration example demonstrates several advanced patterns:

## Key Matrix Features:

**Multiple Time Windows**: The `timeInWeek` array allows you to define multiple maintenance windows across different days and hours, creating a matrix of available maintenance slots.

**Complex Exclusion Patterns**: The `notAllowedTime` array creates a matrix of blocked periods, including:
- Recurring business hours exclusions
- Holiday blackout periods
- Peak traffic exclusions
- Quarterly business review periods

**Multi-Region Considerations**: The third example shows how to handle global deployments with maintenance windows optimized for different time zones.

**Flexible Scheduling**: You can combine:
- Weekly recurring patterns
- Specific date ranges
- Time-zone aware scheduling
- Multiple hour slots per day

The matrix approach gives you fine-grained control over when maintenance can occur by defining both allowed windows (`timeInWeek`) and forbidden periods (`notAllowedTime`). The effective maintenance schedule is the intersection of allowed times minus the blocked periods, creating a complex matrix of available maintenance slots that adapts to your operational requirements.