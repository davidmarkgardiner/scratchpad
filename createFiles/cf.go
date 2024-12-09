func handleAddOrModify(config *Config) error {
	// Determine the correct environment directory
	envDir := config.OpEnvironment
	if strings.ToLower(config.OpEnvironment) == "test" {
		envDir = "dev"
	}

	// Construct the target directory path
	dir := filepath.Join(environmentDir, envDir, config.Region, config.ClusterName,
		fmt.Sprintf("%s-%s-%s", config.Swci, config.OpEnvironment, config.Suffix))
	log.Printf("Target directory: %s", dir)

	// Create the target directory
	if err := os.MkdirAll(dir, os.ModePerm); err != nil {
		return fmt.Errorf("failed to create directory %s: %v", dir, err)
	}
	log.Println("Created target directory")

	// Log all configuration values for debugging
	log.Printf("Config values:")
	v := reflect.ValueOf(*config)
	t := v.Type()
	for i := 0; i < v.NumField(); i++ {
		log.Printf("%s: %v", t.Field(i).Name, v.Field(i).Interface())
	}

	// Handle kustomization files based on conditions
	if config.FullDomainName != "" && strings.HasPrefix(config.GitLabRepoURL, "devcloud.ubs.net") {
		// Case 3: Both conditions met - create git-gate file
		log.Println("Creating kustomization-git-gate.yml (FullDomainName and GitLab repo condition)")
		gitGateSource := filepath.Join(kustomizeDir, "kustomization-gitrepo.yaml")
		if err := processFile(gitGateSource, dir, "kustomization-git-gate.yml", config); err != nil {
			return fmt.Errorf("failed to process git-gate file: %v", err)
		}
	}
	
	if config.FullDomainName != "" {
		// Case 1: FullDomainName present
		log.Println("Creating kustomization-gateway.yaml (FullDomainName provided)")
		gatewaySource := filepath.Join(kustomizeDir, "kustomization-gateway.yaml")
		if err := processFile(gatewaySource, dir, "kustomization-gateway.yaml", config); err != nil {
			return fmt.Errorf("failed to process gateway file: %v", err)
		}
	}
	
	if strings.HasPrefix(config.GitLabRepoURL, "") {
		// Case 2: GitLabRepoURL matches
		log.Println("Creating kustomization-gitrepo.yaml (GitLab repo condition)")
		gitRepoSource := filepath.Join(kustomizeDir, "kustomization-gitrepo.yaml")
		if err := processFile(gitRepoSource, dir, "kustomization-gitrepo.yaml", config); err != nil {
			return fmt.Errorf("failed to process gitrepo file: %v", err)
		}
	}

	if config.FullDomainName == "" && !strings.HasPrefix(config.GitLabRepoURL, "devcloud.ubs.net") {
		// Default case: Neither condition met
		if strings.Contains(config.Suffix, "ob-test") {
			sourceFile := filepath.Join(kustomizeDir, "kustomization-apptest.yaml")
			log.Println("Creating kustomization.yaml from apptest source (ob-test condition)")
			if err := processFile(sourceFile, dir, "kustomization.yaml", config); err != nil {
				return fmt.Errorf("failed to process apptest file: %v", err)
			}
		} else {
			sourceFile := filepath.Join(kustomizeDir, "kustomization.yaml")
			log.Println("Creating kustomization.yaml from default source")
			if err := processFile(sourceFile, dir, "kustomization.yaml", config); err != nil {
				return fmt.Errorf("failed to process default file: %v", err)
			}
		}
	}
