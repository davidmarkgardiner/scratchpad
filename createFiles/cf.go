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

	// Handle kustomization files based on conditions - only create one
	var sourceKustomizationFile string
	var destKustomizationFile string

	if config.FullDomainName != "" && strings.HasPrefix(config.GitLabRepoURL, "sdgois`hbff") {
		// Case 1: Both conditions met - create git-gate file
		sourceKustomizationFile = "kustomization-git-gate.yaml"
		destKustomizationFile = "kustomization.yaml"
		log.Println("Creating kustomization-git-gate.yml (FullDomainName and GitLab repo condition)")
	} else if config.FullDomainName != "" {
		// Case 2: Only FullDomainName present
		sourceKustomizationFile = "kustomization-gateway.yaml"
		destKustomizationFile = "kustomization.yaml"
		log.Println("Creating kustomization.yaml from gateway source (FullDomainName provided)")
	} else if strings.HasPrefix(config.GitLabRepoURL, "sfs`dfdf") {
		// Case 3: Only GitLabRepoURL matches
		sourceKustomizationFile = "kustomization-gitrepo.yaml"
		destKustomizationFile = "kustomization.yaml"
		log.Println("Creating kustomization.yaml from gitrepo source (GitLab repo condition)")
	} else if strings.Contains(config.Suffix, "ob-test") {
		// Case 4: ob-test suffix
		sourceKustomizationFile = "kustomization-apptest.yaml"
		destKustomizationFile = "kustomization.yaml"
		log.Println("Creating kustomization.yaml from apptest source (ob-test condition)")
	} else {
		// Default case
		sourceKustomizationFile = "kustomization.yaml"
		destKustomizationFile = "kustomization.yaml"
		log.Println("Creating kustomization.yaml from default source")
	}

	// Process the selected kustomization file
	sourceFile := filepath.Join(kustomizeDir, sourceKustomizationFile)
	log.Printf("Processing kustomization file: %s", sourceFile)
	if err := processFile(sourceFile, dir, destKustomizationFile, config); err != nil {
		return fmt.Errorf("failed to process kustomization file: %v", err)
	}

	// Process other files
	files, err := filepath.Glob(filepath.Join(kustomizeDir, "*.yaml"))
	if err != nil {
		return fmt.Errorf("failed to glob files: %v", err)
	}
	log.Printf("Found %d YAML files in kustomize overlay directory", len(files))

	for _, file := range files {
		baseFileName := filepath.Base(file)

		// Skip all kustomization files
		if strings.HasPrefix(baseFileName, "kustomization") {
			log.Printf("Skipping kustomization file: %s", baseFileName)
			continue
		}

		// Process gateway.yaml only when FullDomainName is provided
		if baseFileName == "gateway.yaml" {
			if config.FullDomainName != "" {
				log.Printf("Processing gateway.yaml (FullDomainName provided)")
				if err := processFile(file, dir, baseFileName, config); err != nil {
					return err
				}
			} else {
				log.Printf("Skipping gateway.yaml (no FullDomainName provided)")
			}
			continue
		}

		// Process app.yaml only for ob-test
		if baseFileName == "app.yaml" {
			if strings.Contains(config.Suffix, "ob-test") {
				log.Printf("Processing app.yaml for ob-test case")
				if err := processFile(file, dir, baseFileName, config); err != nil {
					return err
				}
			} else {
				log.Printf("Skipping app.yaml for non-ob-test case")
			}
			continue
		}

		log.Printf("Processing non-kustomization file: %s", baseFileName)
		if err := processFile(file, dir, baseFileName, config); err != nil {
			return err
		}
	}

	// Final check
	files, _ = filepath.Glob(filepath.Join(dir, "kustomization*.yaml"))
	log.Printf("Number of kustomization files in target directory: %d", len(files))
	for _, file := range files {
		log.Printf("Kustomization file in target directory: %s", filepath.Base(file))
	}

	return nil
}
