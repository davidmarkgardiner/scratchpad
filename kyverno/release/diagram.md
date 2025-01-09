flowchart TD
    subgraph "GitLab"
        A[Policy Changes] --> B[GitLab Pipeline]
        B --> C[YAML Validation & Build]
        C --> D[Dev Branch]
        D --> E[Staging Branch]
        E --> F[Main Branch]
    end

    subgraph "Azure DevOps"
        G[Dev Policies] --> H[Dev Release]
        I[Staging Policies] --> J[Staging Release]
        K[Prod Policies] --> L[Prod Release]
    end

    D --> G
    E --> I
    F --> K

    subgraph "Clusters"
        M[Dev Cluster]
        N[Staging Cluster]
        O[Prod Cluster]
    end

    H --> |GitOps Sync| M
    J --> |GitOps Sync| N
    L --> |GitOps Sync| O

    %% Helm Test Validations
    M --> |Helm Test| P[Dev Validation]
    N --> |Helm Test| Q[Staging Validation]
    O --> |Helm Test| R[Prod Validation]
