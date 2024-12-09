package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"

	"log"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	// "text/template"
)

const (
	environmentDir = "environment"
	kustomizeDir   = "kustomize/overlay"
)

// Config holds all the configuration options loaded from environment variables
type Config struct {
	Action                 string
	Swci                   string
	Suffix                 string
	Region                 string
	OpEnvironment          string
	ResourceQuotaCPU       string
	ResourceQuotaMemoryGB  string
	ResourceQuotaStorageGB string
	BillingReference       string
	Source                 string
	SwcID                  string
	DataClassification     string
	AppSubDomain           string
	AllowAccessFromNS      string
	RequestedBy            string
	Sub                    string
	Rg                     string
	ClusterName            string
	ID                     string
	NamespaceName          string
	AksClusterResourceId   string
	GitLabRepoURL          string
	BranchName             string
	FolderPath             string
	FullDomainName         string
}

func main() {
	// Set up logging to include line numbers
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	log.Println("Starting the script...")

	// Load configuration from environment variables
	config, err := loadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Determine which action to take based on the 'Action' field
	switch strings.ToLower(config.Action) {
	case "add", "modify":
		log.Println("Performing add/modify action...")
		err = handleAddOrModify(config)
	case "remove":
		log.Println("Performing remove action...")
		err = handleRemove(config)
	default:
		log.Fatalf("Unknown action: %s", config.Action)
	}

	if err != nil {
		log.Fatalf("Operation failed: %v", err)
	}

	log.Println("Script completed successfully.")
}

// loadConfig reads environment variables and populates the Config struct
func loadConfig() (*Config, error) {
	log.Println("Loading configuration from environment variables...")
	config := &Config{}
	v := reflect.ValueOf(config).Elem()

	for i := 0; i < v.NumField(); i++ {
		field := v.Type().Field(i)
		envVar := strings.ToUpper(field.Name)
		value := os.Getenv(envVar)
		v.Field(i).SetString(value)
		log.Printf("Loaded %s: %s", envVar, value)
	}

	// Generate random ID
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return nil, fmt.Errorf("failed to generate random ID: %v", err)
	}
	config.ID = hex.EncodeToString(b)
	log.Printf("Generated random ID: %s", config.ID)

	log.Printf("Loaded GITLAB_REPO_URL: %s", config.GitLabRepoURL)
	log.Printf("Loaded BRANCH_NAME: %s", config.BranchName)
	log.Printf("Loaded FOLDER_PATH: %s", config.FolderPath)

	// Set default values and perform transformations
	if config.AppSubDomain == "" {
		config.AppSubDomain = fmt.Sprintf("%s-%s-%s", config.Swci, config.OpEnvironment, config.Suffix)
		log.Printf("Set default AppSubDomain: %s", config.AppSubDomain)
	}
	if config.ResourceQuotaCPU == "" {
		config.ResourceQuotaCPU = "4"
		log.Println("Set default ResourceQuotaCPU: 4")
	}
	if config.ResourceQuotaMemoryGB == "" {
		config.ResourceQuotaMemoryGB = "8"
		log.Println("Set default ResourceQuotaMemoryGB: 8")
	}
	if config.ResourceQuotaStorageGB == "" {
		config.ResourceQuotaStorageGB = "0"
		log.Println("Set default ResourceQuotaStorageGB: 0")
	}

	// Apply case transformations
	log.Println("Applying case transformations...")
	config.Action = strings.ToLower(config.Action)
	config.Swci = strings.ToLower(config.Swci)
	config.Suffix = strings.ToLower(config.Suffix)
	config.Region = strings.ToLower(config.Region)
	config.OpEnvironment = strings.ToLower(config.OpEnvironment)
	config.Sub = strings.ToLower(config.Sub)
	config.Rg = strings.ToLower(config.Rg)
	config.ClusterName = strings.ToLower(config.ClusterName)
	config.DataClassification = strings.ToLower(config.DataClassification)
	config.AppSubDomain = strings.ToLower(config.AppSubDomain)
	config.AllowAccessFromNS = strings.ToLower(config.AllowAccessFromNS)
	config.RequestedBy = strings.ToLower(config.RequestedBy)
	config.GitLabRepoURL = strings.ToLower(config.GitLabRepoURL)
	config.BranchName = strings.ToLower(config.BranchName)
	config.FolderPath = strings.ToLower(config.FolderPath)
	config.NamespaceName = strings.ToLower(config.NamespaceName)

	config.BillingReference = strings.ToUpper(config.BillingReference)
	config.Source = strings.ToUpper(config.Source)
	config.SwcID = strings.ToUpper(config.SwcID)

	return config, nil
}

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

	// Determine which kustomization file to use as source
	var sourceKustomizationFile string
	if config.FullDomainName != "" {
		sourceKustomizationFile = "kustomization-gateway.yaml"
		log.Println("Using kustomization-gateway.yaml as source (FullDomainName provided)")

		// If both conditions are met, create an additional git-gate file
		if strings.HasPrefix(config.GitLabRepoURL, "devcloud.ubs.net") {
			log.Println("Creating additional kustomization-git-gate.yml (FullDomainName and GitLab repo condition)")
			gitGateSource := filepath.Join(kustomizeDir, "kustomization-gitrepo.yaml")
			if err := processFile(gitGateSource, dir, "kustomization-git-gate.yml", config); err != nil {
				return fmt.Errorf("failed to process git-gate file: %v", err)
			}
		}
	} else if strings.Contains(config.Suffix, "ob-test") {
		sourceKustomizationFile = "kustomization-apptest.yaml"
		log.Println("Using kustomization-apptest.yaml as source (ob-test condition)")
	} else if strings.HasPrefix(config.GitLabRepoURL, "..net") {
		sourceKustomizationFile = "kustomization-gitrepo.yaml"
		log.Println("Using kustomization-gitrepo.yaml as source (GitLab repo condition)")
	} else {
		sourceKustomizationFile = "kustomization.yaml"
		log.Println("Using kustomization.yaml as source (default condition)")
	}

	// Process kustomization file
	sourceFile := filepath.Join(kustomizeDir, sourceKustomizationFile)
	log.Printf("Processing kustomization file: %s", sourceFile)
	if err := processFile(sourceFile, dir, "kustomization.yaml", config); err != nil {
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

// handleRemove processes the 'remove' action
func handleRemove(config *Config) error {
	// Construct the target directory path
	dir := filepath.Join(environmentDir, config.OpEnvironment, config.Region, config.ClusterName,
		fmt.Sprintf("%s-%s-%s", config.Swci, config.OpEnvironment, config.Suffix))
	log.Printf("Target directory for removal: %s", dir)

	// Process the kustomization-delete.yaml file
	deleteFile := filepath.Join(kustomizeDir, "kustomization-delete.yaml")
	log.Printf("Processing kustomization-delete file: %s", deleteFile)
	if err := processFile(deleteFile, dir, "kustomization.yaml", config); err != nil {
		return err
	}

	// // Rename kustomization-delete.yaml to kustomization.yaml
	// log.Println("Renaming kustomization-delete.yaml to kustomization.yaml...")
	// if err := os.Rename(filepath.Join(dir, "kustomization-delete.yaml"), filepath.Join(dir, "kustomization.yaml")); err != nil {
	// 	return fmt.Errorf("failed to rename kustomization-delete.yaml: %v", err)
	// }

	// Remove all other YAML files in the directory
	files, err := filepath.Glob(filepath.Join(dir, "*.yaml"))
	if err != nil {
		return fmt.Errorf("failed to glob files: %v", err)
	}
	log.Printf("Found %d YAML files in target directory", len(files))

	for _, file := range files {
		if filepath.Base(file) != "kustomization.yaml" {
			log.Printf("Removing file: %s", file)
			if err := os.Remove(file); err != nil {
				return fmt.Errorf("failed to remove file %s: %v", file, err)
			}
		}
	}

	return nil
}

func processFile(srcFile, destDir, destFileName string, config *Config) error {
	log.Printf("Processing file %s as %s", srcFile, destFileName)

	// Read the source file
	content, err := os.ReadFile(srcFile)
	if err != nil {
		return fmt.Errorf("failed to read file %s: %v", srcFile, err)
	}

	// Replace placeholders in the content
	replacedContent := string(content)
	v := reflect.ValueOf(*config)
	t := v.Type()

	for i := 0; i < v.NumField(); i++ {
		fieldName := t.Field(i).Name
		fieldValue := v.Field(i).String()
		placeholder := "${" + strings.ToLower(fieldName) + "}"
		replacedContent = strings.ReplaceAll(replacedContent, placeholder, fieldValue)
	}

	// Create the destination file
	destFile := filepath.Join(destDir, destFileName)
	if err := os.WriteFile(destFile, []byte(replacedContent), 0644); err != nil {
		return fmt.Errorf("failed to write file %s: %v", destFile, err)
	}

	log.Printf("Successfully processed and wrote file: %s", destFile)
	return nil
}
